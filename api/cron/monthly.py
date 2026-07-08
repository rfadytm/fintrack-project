"""GET /api/cron/monthly — dipanggil GitHub Actions tanggal 1 tiap bulan.
Auth: header X-Cron-Secret.

Month-over-month: bandingkan bulan yang BARU SAJA berakhir vs bulan sebelumnya.
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import telegram as tg
from shared.db import get_client
from shared.format import bulan_nama, rupiah, today_wib
from shared.http import require_cron, send_json

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))


def _shift_month(year, month, delta):
    idx = (year * 12 + (month - 1)) + delta
    return idx // 12, idx % 12 + 1


def _month_totals(db, year, month):
    res = db.table("monthly_summary").select("*").eq("period_year", year).eq("period_month", month).execute()
    income = expense = 0
    for r in res.data:
        if r["account_type"] == "pendapatan":
            income += r["total_credit"] - r["total_debit"]
        elif r["account_type"] == "beban":
            expense += r["total_debit"] - r["total_credit"]
    return income, expense


def _pct_change(new, old):
    if old == 0:
        return None
    return round((new - old) / abs(old) * 100, 1)


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        db = get_client()
        today = today_wib()
        last_y, last_m = _shift_month(today.year, today.month, -1)
        prev_y, prev_m = _shift_month(today.year, today.month, -2)

        last_income, last_expense = _month_totals(db, last_y, last_m)
        prev_income, prev_expense = _month_totals(db, prev_y, prev_m)

        income_chg = _pct_change(last_income, prev_income)
        expense_chg = _pct_change(last_expense, prev_expense)

        if OWNER_ID:
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

        send_json(self, 200, {"ok": True})
