"""GET /api/recurring — daftar transaksi berulang aktif.
POST /api/recurring — buat/update: {"id"?,"doc_type","description","lines","frequency","next_run"?,"is_active"?}.
DELETE /api/recurring?id= — nonaktifkan (is_active=false).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.format import today_wib
from shared.http import get_query, read_json, require_session, send_json

_DOC_TYPES = {"OB", "KK", "KM", "TR", "JU", "RV"}
_FREQUENCIES = {"daily", "weekly", "monthly"}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        res = (
            get_client()
            .table("recurring_transactions")
            .select("*")
            .eq("is_active", True)
            .order("next_run")
            .execute()
        )
        send_json(self, 200, {"recurring": res.data})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        doc_type = (body.get("doc_type") or "").upper()
        frequency = body.get("frequency")
        lines = body.get("lines")
        if doc_type not in _DOC_TYPES or frequency not in _FREQUENCIES or not lines:
            return send_json(
                self, 400, {"error": "doc_type, frequency (daily/weekly/monthly) & lines wajib"}
            )
        row = {
            "doc_type": doc_type,
            "description": body.get("description"),
            "lines": lines,
            "frequency": frequency,
            "next_run": body.get("next_run") or today_wib().isoformat(),
            "is_active": body.get("is_active", True),
        }
        db = get_client()
        if body.get("id"):
            db.table("recurring_transactions").update(row).eq("id", body["id"]).execute()
        else:
            db.table("recurring_transactions").insert(row).execute()
        send_json(self, 200, {"ok": True})

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        if not q.get("id"):
            return send_json(self, 400, {"error": "id wajib"})
        get_client().table("recurring_transactions").update({"is_active": False}).eq(
            "id", int(q["id"])
        ).execute()
        send_json(self, 200, {"ok": True})
