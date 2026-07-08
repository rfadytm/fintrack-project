"""GET /api/tags — daftar tag.
POST /api/tags — buat tag baru: {"name","emoji"?}.
DELETE /api/tags?id= — hapus tag (dan seluruh assignment-nya via ON DELETE tidak di-set,
jadi hapus transaction_tags dulu di sini biar konsisten).
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
        res = get_client().table("tags").select("*").order("name").execute()
        send_json(self, 200, {"tags": res.data})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        name = (body.get("name") or "").strip()
        if not name:
            return send_json(self, 400, {"error": "name wajib"})
        get_client().table("tags").upsert(
            {"name": name, "emoji": body.get("emoji")}, on_conflict="name"
        ).execute()
        send_json(self, 200, {"ok": True})

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        if not q.get("id"):
            return send_json(self, 400, {"error": "id wajib"})
        db = get_client()
        db.table("transaction_tags").delete().eq("tag_id", int(q["id"])).execute()
        db.table("tags").delete().eq("id", int(q["id"])).execute()
        send_json(self, 200, {"ok": True})
