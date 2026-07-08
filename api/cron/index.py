"""GET /api/cron?job=daily|weekly|monthly|annual|housekeeping — semua cron job
dalam SATU function (Vercel Hobby cap 12 Serverless Functions/deployment — lihat
catatan di api/reports/index.py). Dipanggil GitHub Actions
(.github/workflows/scheduled-reports.yml), auth via header X-Cron-Secret.

job=daily         (09:00 WIB) — ringkasan hari ini + auto-post recurring jatuh
                  tempo + reminder tagihan H-3
job=weekly        (Minggu)    — breakdown kategori + sparkline + deteksi
                  anomali (z-score, mingguan sesuai keputusan user) + progress goals
job=monthly       (tgl 1)     — month-over-month vs bulan sebelumnya
job=annual        (1 Jan)     — ringkasan tahun yang baru berakhir
job=housekeeping  (tiap 30m)  — sapu bot_state macet >30 menit, notify + reset
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import date as _date, datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler

from shared import journal, telegram as tg
from shared.db import get_client
from shared.forecast import is_anomaly, threshold_for
from shared.format import bulan_nama, fmt_date, rupiah, today_wib
from shared.http import get_query, require_cron, send_json
from shared.reports import month_totals
from shared.scheduling import advance_next_run, bill_due_this_cycle, days_until, period_str
from shared.sparkline import render as sparkline

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))


def _setting(db, key, default=None):
    res = db.table("bot_settings").select("value").eq("key", key).execute()
    return res.data[0]["value"] if res.data else default


def _shift_month(year, month, delta):
    idx = (year * 12 + (month - 1)) + delta
    return idx // 12, idx % 12 + 1


# ============================================================
# daily
# ============================================================
def _send_daily_summary(db, today):
    if _setting(db, "daily_report_enabled", "true") != "true":
        return
    res = (
        db.table("journal_lines")
        .select(
            "debit_amount, credit_amount, chart_of_accounts(account_type), "
            "transactions!inner(transaction_date, status)"
        )
        .eq("transactions.transaction_date", today.isoformat())
        .eq("transactions.status", "POSTED")
        .execute()
    )
    income = expense = 0
    for r in res.data:
        acc = r.get("chart_of_accounts") or {}
        if acc.get("account_type") == "pendapatan":
            income += (r["credit_amount"] or 0) - (r["debit_amount"] or 0)
        elif acc.get("account_type") == "beban":
            expense += (r["debit_amount"] or 0) - (r["credit_amount"] or 0)
    if not OWNER_ID:
        return
    tg.send_message(
        OWNER_ID,
        f"☀️ <b>Ringkasan {fmt_date(today)}</b>\n\n"
        f"💰 Pemasukan: {rupiah(income)}\n"
        f"💸 Pengeluaran: {rupiah(expense)}\n"
        f"📈 Net: {rupiah(income - expense)}",
    )


def _execute_recurring(db, today):
    due = (
        db.table("recurring_transactions")
        .select("*")
        .eq("is_active", True)
        .lte("next_run", today.isoformat())
        .execute()
    )
    for r in due.data:
        try:
            doc = journal.post(r["doc_type"], today, r.get("description"), r["lines"], source="system")
            next_run = advance_next_run(today, r["frequency"])
            db.table("recurring_transactions").update({"next_run": next_run.isoformat()}).eq("id", r["id"]).execute()
            if OWNER_ID:
                tg.send_message(OWNER_ID, f"🔁 Recurring \"{r['description']}\" ter-posting otomatis: {doc}.")
        except Exception as e:
            if OWNER_ID:
                tg.send_message(OWNER_ID, f"⚠️ Recurring #{r['id']} \"{r.get('description')}\" gagal diposting: {e}")


def _send_bill_reminders(db, today):
    bills = db.table("bills").select("*").eq("is_active", True).execute()
    for b in bills.data:
        if b.get("due_day"):
            due = bill_due_this_cycle(b["due_day"], today)
        elif b.get("due_date"):
            due = _date.fromisoformat(b["due_date"])
        else:
            continue
        if days_until(due, today) > 3 or days_until(due, today) < 0:
            continue
        this_period = period_str(due)
        if b.get("last_reminded_period") == this_period:
            continue
        if OWNER_ID:
            tg.send_message(
                OWNER_ID, f"📅 <b>Tagihan jatuh tempo</b>: {b['name']} — {rupiah(b['amount'])} ({fmt_date(due)})"
            )
        db.table("bills").update({"last_reminded_period": this_period}).eq("id", b["id"]).execute()


def _check_end_of_month(db, today):
    """Hari terakhir bulan ini? Tawarkan nabung sisa bulan (user request) —
    tombolnya (eom_save:<amount> / eom_skip) di-handle di api/telegram/webhook.py,
    reuse alur transfer-ke-tabungan yang sudah ada (fee_rule/build_transfer_lines)."""
    tomorrow = today + timedelta(days=1)
    if tomorrow.month == today.month or not OWNER_ID:
        return  # bukan hari terakhir bulan ini
    income, expense = month_totals(db, today.year, today.month)
    net = income - expense
    if net <= 0:
        return
    savings_code = _setting(db, "savings_account", "1140")
    acc = db.table("chart_of_accounts").select("account_name").eq("code", savings_code).execute()
    savings_name = acc.data[0]["account_name"] if acc.data else savings_code
    tg.send_message(
        OWNER_ID,
        f"🌙 <b>Akhir bulan!</b>\n\nSisa bulan ini: <b>{rupiah(net)}</b>\nMau ditabung ke {savings_name} ({savings_code})?",
        keyboard=[[tg.btn(f"✅ Tabung {rupiah(net)}", f"eom_save:{net}"), tg.btn("❌ Nanti saja", "eom_skip")]],
    )


def job_daily(db):
    today = today_wib()
    _send_daily_summary(db, today)
    _execute_recurring(db, today)
    _send_bill_reminders(db, today)
    _check_end_of_month(db, today)


# ============================================================
# weekly
# ============================================================
def _week_range(today):
    return today - timedelta(days=6), today


def _daily_expense_totals(db, start, end):
    res = (
        db.table("journal_lines")
        .select("debit_amount, chart_of_accounts(account_type), transactions!inner(transaction_date, status)")
        .eq("transactions.status", "POSTED")
        .gte("transactions.transaction_date", start.isoformat())
        .lte("transactions.transaction_date", end.isoformat())
        .execute()
    )
    by_day = {}
    for r in res.data:
        acc = r.get("chart_of_accounts") or {}
        if acc.get("account_type") != "beban":
            continue
        d = r["transactions"]["transaction_date"]
        by_day[d] = by_day.get(d, 0) + (r["debit_amount"] or 0)
    return by_day


def _category_breakdown(db, start, end):
    res = (
        db.table("journal_lines")
        .select(
            "account_code, debit_amount, chart_of_accounts(account_name, account_type), "
            "transactions!inner(transaction_date, status)"
        )
        .eq("transactions.status", "POSTED")
        .gte("transactions.transaction_date", start.isoformat())
        .lte("transactions.transaction_date", end.isoformat())
        .execute()
    )
    totals = {}
    for r in res.data:
        acc = r.get("chart_of_accounts") or {}
        if acc.get("account_type") != "beban":
            continue
        key = r["account_code"]
        row = totals.setdefault(key, {"account_name": acc.get("account_name"), "amount": 0})
        row["amount"] += r["debit_amount"] or 0
    return sorted(totals.values(), key=lambda r: -r["amount"])


def _send_weekly_breakdown(db, today):
    if _setting(db, "weekly_report_enabled", "true") != "true":
        return
    start, end = _week_range(today)
    by_day = _daily_expense_totals(db, start, end)
    series = [by_day.get((start + timedelta(days=i)).isoformat(), 0) for i in range(7)]
    breakdown = _category_breakdown(db, start, end)
    lines = [f"📊 <b>Ringkasan Minggu Ini</b> ({fmt_date(start)}–{fmt_date(end)})\n"]
    lines.append(f"Tren harian: {sparkline(series)}\n")
    if breakdown:
        lines.append("<b>Top kategori:</b>")
        for row in breakdown[:5]:
            lines.append(f"• {row['account_name']}: {rupiah(row['amount'])}")
    if OWNER_ID:
        tg.send_message(OWNER_ID, "\n".join(lines))


def _send_anomaly_report(db, today):
    sensitivity = _setting(db, "alert_sensitivity", "normal")
    threshold = threshold_for(sensitivity)
    this_start, this_end = _week_range(today)
    this_week = {row["account_name"]: row["amount"] for row in _category_breakdown(db, this_start, this_end)}

    history_by_cat = {}
    for w in range(1, 9):
        start = this_start - timedelta(days=7 * w)
        end = this_end - timedelta(days=7 * w)
        for row in _category_breakdown(db, start, end):
            history_by_cat.setdefault(row["account_name"], []).append(row["amount"])

    flagged = []
    for name, amount in this_week.items():
        history = history_by_cat.get(name, [])
        if len(history) >= 4 and is_anomaly(amount, history, threshold):
            flagged.append((name, amount))

    if flagged and OWNER_ID:
        lines = ["🔍 <b>Anomali minggu ini</b>\n"]
        for name, amount in flagged:
            lines.append(f"• {name}: {rupiah(amount)} — jauh dari kebiasaan")
        tg.send_message(OWNER_ID, "\n".join(lines))


def _send_goal_progress(db):
    res = db.table("goals").select("*").eq("is_active", True).execute()
    if not res.data or not OWNER_ID:
        return
    lines = ["🎯 <b>Progress Goals</b>"]
    for g in res.data:
        current = 0
        if g.get("account_code"):
            bal = db.table("account_balances").select("balance").eq("code", g["account_code"]).execute()
            current = bal.data[0]["balance"] if bal.data else 0
        pct = min(round(current / g["target_amount"] * 100), 100) if g["target_amount"] else 0
        bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
        lines.append(f"\n<b>{g['name']}</b>\n{rupiah(current)} / {rupiah(g['target_amount'])}\n{bar} {pct}%")
    tg.send_message(OWNER_ID, "\n".join(lines))


def job_weekly(db):
    today = today_wib()
    _send_weekly_breakdown(db, today)
    _send_anomaly_report(db, today)
    _send_goal_progress(db)


# ============================================================
# monthly
# ============================================================
def _pct_change(new, old):
    if old == 0:
        return None
    return round((new - old) / abs(old) * 100, 1)


def job_monthly(db):
    today = today_wib()
    last_y, last_m = _shift_month(today.year, today.month, -1)
    prev_y, prev_m = _shift_month(today.year, today.month, -2)
    last_income, last_expense = month_totals(db, last_y, last_m)
    prev_income, prev_expense = month_totals(db, prev_y, prev_m)
    income_chg = _pct_change(last_income, prev_income)
    expense_chg = _pct_change(last_expense, prev_expense)
    if not OWNER_ID:
        return
    lines = [f"📆 <b>{bulan_nama(last_m)} {last_y}</b> vs {bulan_nama(prev_m)} {prev_y}\n"]
    lines.append(
        f"💰 Pemasukan: {rupiah(last_income)}"
        + (f" ({'+' if income_chg and income_chg >= 0 else ''}{income_chg}%)" if income_chg is not None else "")
    )
    lines.append(
        f"💸 Pengeluaran: {rupiah(last_expense)}"
        + (f" ({'+' if expense_chg and expense_chg >= 0 else ''}{expense_chg}%)" if expense_chg is not None else "")
    )
    lines.append(f"📈 Net: {rupiah(last_income - last_expense)}")
    tg.send_message(OWNER_ID, "\n".join(lines))


# ============================================================
# annual
# ============================================================
def job_annual(db):
    year = today_wib().year - 1
    res = db.table("monthly_summary").select("*").eq("period_year", year).execute()
    income = expense = 0
    for r in res.data:
        if r["account_type"] == "pendapatan":
            income += r["total_credit"] - r["total_debit"]
        elif r["account_type"] == "beban":
            expense += r["total_debit"] - r["total_credit"]
    net = income - expense
    savings_rate = round(net / income * 100, 1) if income > 0 else None

    breakdown = (
        db.table("journal_lines")
        .select(
            "debit_amount, chart_of_accounts(account_name, account_type), transactions!inner(period_year, status)"
        )
        .eq("transactions.period_year", year)
        .eq("transactions.status", "POSTED")
        .execute()
    )
    totals = {}
    for r in breakdown.data:
        acc = r.get("chart_of_accounts") or {}
        if acc.get("account_type") != "beban":
            continue
        name = acc.get("account_name")
        totals[name] = totals.get(name, 0) + (r["debit_amount"] or 0)
    top5 = sorted(totals.items(), key=lambda x: -x[1])[:5]

    if not OWNER_ID:
        return
    lines = [f"🎊 <b>Ringkasan Tahun {year}</b>\n"]
    lines.append(f"💰 Total Pemasukan: {rupiah(income)}")
    lines.append(f"💸 Total Pengeluaran: {rupiah(expense)}")
    lines.append(f"📈 Net: {rupiah(net)}")
    if savings_rate is not None:
        lines.append(f"💾 Savings rate: {savings_rate}%")
    if top5:
        lines.append("\n<b>Top 5 kategori beban:</b>")
        for name, amt in top5:
            lines.append(f"• {name}: {rupiah(amt)}")
    tg.send_message(OWNER_ID, "\n".join(lines))


# ============================================================
# housekeeping
# ============================================================
def job_housekeeping(db):
    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()
    stale = (
        db.table("bot_state")
        .select("user_id, state, updated_at")
        .neq("state", "IDLE")
        .lt("updated_at", cutoff)
        .execute()
    )
    for row in stale.data:
        db.table("bot_state").update({"state": "IDLE", "state_data": {}}).eq("user_id", row["user_id"]).execute()
        try:
            tg.send_message(
                row["user_id"],
                "⏳ Input yang belum selesai (>30 menit tanpa aktivitas) sudah dibatalkan otomatis. Ketik /menu untuk mulai lagi.",
            )
        except Exception:
            pass
    return len(stale.data)


_JOBS = {
    "daily": job_daily,
    "weekly": job_weekly,
    "monthly": job_monthly,
    "annual": job_annual,
}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        q = get_query(self)
        job = q.get("job")
        db = get_client()
        if job == "housekeeping":
            swept = job_housekeeping(db)
            return send_json(self, 200, {"ok": True, "swept": swept})
        fn = _JOBS.get(job)
        if not fn:
            return send_json(self, 400, {"error": f"job tidak dikenal: {job!r}. Pilihan: {sorted(_JOBS) + ['housekeeping']}"})
        fn(db)
        send_json(self, 200, {"ok": True})
