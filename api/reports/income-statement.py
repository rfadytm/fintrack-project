"""GET /api/reports/income-statement?year=&month= — Laba Rugi per bulan."""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        if not q.get("year") or not q.get("month"):
            return send_json(self, 400, {"error": "year & month wajib"})
        year, month = int(q["year"]), int(q["month"])

        res = get_client().rpc(
            "income_statement", {"p_year": year, "p_month": month}
        ).execute()
        rows = res.data or []
        revenue = [r for r in rows if r["account_type"] == "pendapatan"]
        expense = [r for r in rows if r["account_type"] == "beban"]
        total_rev = sum(r["amount"] for r in revenue)
        total_exp = sum(r["amount"] for r in expense)

        send_json(
            self,
            200,
            {
                "year": year,
                "month": month,
                "revenue": revenue,
                "expense": expense,
                "total_revenue": total_rev,
                "total_expense": total_exp,
                "net_income": total_rev - total_exp,
            },
        )
