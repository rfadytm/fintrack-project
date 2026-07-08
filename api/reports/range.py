"""GET /api/reports/range?date_from=&date_to= — laba/rugi untuk rentang tanggal bebas
(bukan year/month kalender seperti /reports/income-statement). Agregasi di Python,
mirip gaya ledger.py — tidak butuh RPC baru.
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import date
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        raw_from, raw_to = q.get("date_from"), q.get("date_to")
        if not raw_from or not raw_to:
            return send_json(self, 400, {"error": "date_from & date_to (YYYY-MM-DD) wajib"})
        try:
            date_from = date.fromisoformat(raw_from)
            date_to = date.fromisoformat(raw_to)
        except ValueError:
            return send_json(self, 400, {"error": "format tanggal harus YYYY-MM-DD"})
        if date_from > date_to:
            return send_json(self, 400, {"error": "date_from harus <= date_to"})

        db = get_client()
        res = (
            db.table("journal_lines")
            .select(
                "account_code, debit_amount, credit_amount, "
                "chart_of_accounts(account_name, account_type), "
                "transactions!inner(status, transaction_date)"
            )
            .eq("transactions.status", "POSTED")
            .gte("transactions.transaction_date", date_from.isoformat())
            .lte("transactions.transaction_date", date_to.isoformat())
            .execute()
        )

        by_account = {}
        for r in res.data:
            acc = r.get("chart_of_accounts") or {}
            acc_type = acc.get("account_type")
            if acc_type not in ("pendapatan", "beban"):
                continue
            key = r["account_code"]
            row = by_account.setdefault(
                key, {"code": key, "account_name": acc.get("account_name"), "account_type": acc_type, "amount": 0}
            )
            if acc_type == "pendapatan":
                row["amount"] += (r["credit_amount"] or 0) - (r["debit_amount"] or 0)
            else:
                row["amount"] += (r["debit_amount"] or 0) - (r["credit_amount"] or 0)

        revenue = [r for r in by_account.values() if r["account_type"] == "pendapatan"]
        expense = [r for r in by_account.values() if r["account_type"] == "beban"]
        total_revenue = sum(r["amount"] for r in revenue)
        total_expense = sum(r["amount"] for r in expense)

        send_json(
            self,
            200,
            {
                "date_from": date_from.isoformat(),
                "date_to": date_to.isoformat(),
                "revenue": revenue,
                "expense": expense,
                "total_revenue": total_revenue,
                "total_expense": total_expense,
                "net_income": total_revenue - total_expense,
            },
        )
