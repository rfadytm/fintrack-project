"""GET /api/transactions  — list transaksi + journal lines (B13 pagination).
POST /api/transactions — buat transaksi baru (double-entry) untuk integrasi.

POST auth: session cookie (dashboard) ATAU header X-API-Key (project lain).
Body JSON:
  {
    "doc_type": "KK",                       # OB|KK|KM|TR|JU|RV
    "date": "2026-07-03",                   # opsional, default hari ini (WIB)
    "description": "Belanja Indomaret",
    "lines": [
      {"account_code": "5130", "debit": 45000, "credit": 0},
      {"account_code": "1130", "debit": 0, "credit": 45000}
    ]
  }
Return: {"doc_number": "KK-2026-07-001"}.
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import date as _date
from http.server import BaseHTTPRequestHandler

from shared import journal
from shared.db import get_client
from shared.format import today_wib
from shared.http import get_query, paginate, read_json, require_auth, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        auth = require_auth(self)
        if not auth:
            return
        body = read_json(self)

        doc_type = (body.get("doc_type") or "").upper()
        description = body.get("description")
        lines = body.get("lines")

        raw_date = body.get("date")
        try:
            tx_date = _date.fromisoformat(raw_date) if raw_date else today_wib()
        except (ValueError, TypeError):
            return send_json(self, 400, {"error": "date harus format YYYY-MM-DD"})

        source = "dashboard" if auth.get("via") == "session" else "system"
        try:
            doc = journal.post(doc_type, tx_date, description, lines, source=source)
        except journal.JournalError as e:
            return send_json(self, 400, {"error": str(e)})
        except ValueError as e:                      # doc_type invalid dari gen_doc
            return send_json(self, 400, {"error": str(e)})
        except Exception as e:                        # balance/period-lock guard dari RPC
            return send_json(self, 400, {"error": f"gagal posting: {e}"})

        send_json(self, 201, {"doc_number": doc})

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
