"""GET /api/reports/trial-balance?year=&month= — trial balance cumulative + verify balance."""
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
            "trial_balance", {"p_year": year, "p_month": month}
        ).execute()
        rows = res.data or []
        total_debit = sum(r["total_debit"] for r in rows)
        total_credit = sum(r["total_credit"] for r in rows)

        send_json(
            self,
            200,
            {
                "year": year,
                "month": month,
                "accounts": rows,
                "total_debit": total_debit,
                "total_credit": total_credit,
                "balanced": total_debit == total_credit,
            },
        )
