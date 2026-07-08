"""GET /api/goals — daftar goal + progress live (saldo account_code).
POST /api/goals — buat/update: {"id"?,"name","target_amount","account_code","target_date"?}.
DELETE /api/goals?id= — nonaktifkan goal (is_active=false, bukan hard delete).
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
        db = get_client()
        res = db.table("goals").select("*").eq("is_active", True).execute()
        goals = []
        for g in res.data:
            current = 0
            if g.get("account_code"):
                bal = db.table("account_balances").select("balance").eq("code", g["account_code"]).execute()
                current = bal.data[0]["balance"] if bal.data else 0
            goals.append({**g, "current_amount": current})
        send_json(self, 200, {"goals": goals})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        name = body.get("name")
        target = body.get("target_amount")
        if not name or not isinstance(target, (int, float)) or target <= 0:
            return send_json(self, 400, {"error": "name & target_amount (>0) wajib"})
        row = {
            "name": name,
            "target_amount": int(target),
            "account_code": body.get("account_code"),
            "target_date": body.get("target_date"),
        }
        db = get_client()
        if body.get("id"):
            db.table("goals").update(row).eq("id", body["id"]).execute()
        else:
            db.table("goals").insert(row).execute()
        send_json(self, 200, {"ok": True})

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        if not q.get("id"):
            return send_json(self, 400, {"error": "id wajib"})
        get_client().table("goals").update({"is_active": False}).eq("id", int(q["id"])).execute()
        send_json(self, 200, {"ok": True})
