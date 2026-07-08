"""GET /api/cron/daily — dipanggil GitHub Actions tiap hari (lihat
.github/workflows/scheduled-reports.yml). Auth: header X-Cron-Secret.

Tiga hal sekaligus (semua cadence harian, dibundel biar 1 cron job):
1. Kirim ringkasan pengeluaran hari ini (kalau daily_report_enabled=true).
2. Eksekusi recurring_transactions yang next_run <= hari ini.
3. Kirim reminder bills yang jatuh tempo dalam <=3 hari (throttle per bulan).
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import journal, telegram as tg
from shared.db import get_client
from shared.format import fmt_date, rupiah, today_wib
from shared.http import require_cron, send_json
from shared.scheduling import advance_next_run, bill_due_this_cycle, days_until, period_str

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))


def _setting(db, key, default=None):
    res = db.table("bot_settings").select("value").eq("key", key).execute()
    return res.data[0]["value"] if res.data else default


def send_daily_summary(db, today):
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


def execute_recurring(db, today):
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
                tg.send_message(
                    OWNER_ID,
                    f"🔁 Recurring \"{r['description']}\" ter-posting otomatis: {doc}.",
                )
        except Exception as e:
            if OWNER_ID:
                tg.send_message(OWNER_ID, f"⚠️ Recurring #{r['id']} \"{r.get('description')}\" gagal diposting: {e}")


def send_bill_reminders(db, today):
    bills = db.table("bills").select("*").eq("is_active", True).execute()
    for b in bills.data:
        if b.get("due_day"):
            due = bill_due_this_cycle(b["due_day"], today)
        elif b.get("due_date"):
            from datetime import date as _date

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
                OWNER_ID,
                f"📅 <b>Tagihan jatuh tempo</b>: {b['name']} — {rupiah(b['amount'])} ({fmt_date(due)})",
            )
        db.table("bills").update({"last_reminded_period": this_period}).eq("id", b["id"]).execute()


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        db = get_client()
        today = today_wib()
        send_daily_summary(db, today)
        execute_recurring(db, today)
        send_bill_reminders(db, today)
        send_json(self, 200, {"ok": True})
