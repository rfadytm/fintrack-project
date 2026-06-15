"""GET /api/reports/ledger?account=&year=&month= — buku besar per akun."""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, paginate, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        account = q.get("account")
        if not account:
            return send_json(self, 400, {"error": "account wajib"})
        limit, offset = paginate(q, default_limit=100)
        db = get_client()

        # journal_lines untuk akun + join transaksi (POSTED) dengan filter periode
        query = (
            db.table("journal_lines")
            .select(
                "id, line_order, debit_amount, credit_amount, "
                "transactions!inner(doc_number, transaction_date, description, status, period_year, period_month)",
                count="exact",
            )
            .eq("account_code", account)
            .eq("transactions.status", "POSTED")
        )
        if q.get("year"):
            query = query.eq("transactions.period_year", int(q["year"]))
        if q.get("month"):
            query = query.eq("transactions.period_month", int(q["month"]))

        res = query.range(offset, offset + limit - 1).execute()

        rows = sorted(
            res.data, key=lambda r: r["transactions"]["transaction_date"]
        )
        running = 0
        for r in rows:
            running += r["debit_amount"] - r["credit_amount"]
            r["running_balance"] = running

        send_json(
            self,
            200,
            {"account": account, "lines": rows, "total": res.count},
        )
