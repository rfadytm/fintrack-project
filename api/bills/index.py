"""GET /api/bills — daftar tagihan aktif.
POST /api/bills — buat/update: {"id"?,"name","amount","due_day"?,"due_date"?,"is_recurring"?}.
DELETE /api/bills?id= — nonaktifkan (is_active=false).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, read_json, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        res = get_client().table("bills").select("*").eq("is_active", True).execute()
        send_json(self, 200, {"bills": res.data})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        name = body.get("name")
        amount = body.get("amount")
        due_day = body.get("due_day")
        due_date = body.get("due_date")
        if not name or not isinstance(amount, (int, float)) or amount <= 0:
            return send_json(self, 400, {"error": "name & amount (>0) wajib"})
        if not due_day and not due_date:
            return send_json(self, 400, {"error": "due_day (1-31) atau due_date wajib"})
        row = {
            "name": name,
            "amount": int(amount),
            "due_day": due_day,
            "due_date": due_date,
            "is_recurring": body.get("is_recurring", True),
        }
        db = get_client()
        if body.get("id"):
            db.table("bills").update(row).eq("id", body["id"]).execute()
        else:
            db.table("bills").insert(row).execute()
        send_json(self, 200, {"ok": True})

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        if not q.get("id"):
            return send_json(self, 400, {"error": "id wajib"})
        get_client().table("bills").update({"is_active": False}).eq("id", int(q["id"])).execute()
        send_json(self, 200, {"ok": True})
