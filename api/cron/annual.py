"""GET /api/cron/annual — dipanggil GitHub Actions 1 Januari tiap tahun.
Auth: header X-Cron-Secret. Ringkasan tahun yang baru berakhir.
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import telegram as tg
from shared.db import get_client
from shared.format import rupiah, today_wib
from shared.http import require_cron, send_json

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        db = get_client()
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
                "debit_amount, chart_of_accounts(account_name, account_type), "
                "transactions!inner(period_year, status)"
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

        if OWNER_ID:
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

        send_json(self, 200, {"ok": True})
