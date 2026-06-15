"""GET /api/transactions — list transaksi + journal lines (B13 pagination)."""
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
        limit, offset = paginate(q)
        db = get_client()

        query = db.table("transactions").select(
            "*, journal_lines(line_order, account_code, debit_amount, credit_amount)",
            count="exact",
        )
        if q.get("type"):
            query = query.eq("doc_type", q["type"])
        if q.get("status"):
            query = query.eq("status", q["status"])
        if q.get("year"):
            query = query.eq("period_year", int(q["year"]))
        if q.get("month"):
            query = query.eq("period_month", int(q["month"]))

        res = (
            query.order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        send_json(
            self,
            200,
            {
                "transactions": res.data,
                "total": res.count,
                "limit": limit,
                "offset": offset,
            },
        )
