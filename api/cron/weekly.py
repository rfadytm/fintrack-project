"""GET /api/cron/weekly — dipanggil GitHub Actions tiap Minggu (lihat
.github/workflows/scheduled-reports.yml). Auth: header X-Cron-Secret.

Tiga hal (semua cadence mingguan, sesuai keputusan user: anomaly report = mingguan):
1. Breakdown pengeluaran per kategori minggu ini + sparkline 7 hari terakhir.
2. Deteksi anomali (z-score) dibanding rata-rata mingguan 8 minggu terakhir.
3. Progress goals.
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import timedelta
from http.server import BaseHTTPRequestHandler

from shared import telegram as tg
from shared.db import get_client
from shared.forecast import is_anomaly, threshold_for
from shared.format import fmt_date, rupiah, today_wib
from shared.http import require_cron, send_json
from shared.sparkline import render as sparkline

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))


def _setting(db, key, default=None):
    res = db.table("bot_settings").select("value").eq("key", key).execute()
    return res.data[0]["value"] if res.data else default


def _week_range(today):
    start = today - timedelta(days=6)
    return start, today


def _daily_expense_totals(db, start, end):
    res = (
        db.table("journal_lines")
        .select(
            "debit_amount, chart_of_accounts(account_type), "
            "transactions!inner(transaction_date, status)"
        )
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


def send_weekly_breakdown(db, today):
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


def send_anomaly_report(db, today):
    """Bandingkan total pengeluaran per kategori minggu ini vs 8 minggu sebelumnya (z-score)."""
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


def send_goal_progress(db):
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


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        db = get_client()
        today = today_wib()
        send_weekly_breakdown(db, today)
        send_anomaly_report(db, today)
        send_goal_progress(db)
        send_json(self, 200, {"ok": True})
