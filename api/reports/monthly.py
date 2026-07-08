"""GET /api/reports/monthly?year=&month= — summary income vs expense + breakdown beban."""
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
        db = get_client()

        summary = (
            db.table("monthly_summary")
            .select("*")
            .eq("period_year", year)
            .eq("period_month", month)
            .execute()
        )

        # Net income = pendapatan (credit) - beban (debit)
        income = expense = 0
        for r in summary.data:
            if r["account_type"] == "pendapatan":
                income += r["total_credit"] - r["total_debit"]
            elif r["account_type"] == "beban":
                expense += r["total_debit"] - r["total_credit"]

        send_json(
            self,
            200,
            {
                "year": year,
                "month": month,
                "income": income,
                "expense": expense,
                "net": income - expense,
                "savings_rate": round((income - expense) / income, 4) if income > 0 else None,
                "by_type": summary.data,
            },
        )
