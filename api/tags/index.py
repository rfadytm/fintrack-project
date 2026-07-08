"""GET /api/tags — daftar tag.
POST /api/tags — buat tag baru: {"name","emoji"?}.
POST /api/tags?action=assign — pasang/lepas tag pada transaksi:
  {"doc_number","tag_ids":[1,2,...]} (replace total, bukan tambah incremental).
DELETE /api/tags?id= — hapus tag (+ seluruh assignment-nya).

(assign digabung ke sini, bukan file terpisah — Vercel Hobby cap 12 Serverless
Functions/deployment, lihat catatan di api/reports/index.py.)
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, read_json, require_session, send_json


def _assign_tags(db, body):
    doc = body.get("doc_number")
    tag_ids = body.get("tag_ids")
    if not doc or tag_ids is None:
        return 400, {"error": "doc_number & tag_ids wajib"}
    tx = db.table("transactions").select("doc_number").eq("doc_number", doc).execute()
    if not tx.data:
        return 400, {"error": f"dokumen {doc} tidak ditemukan"}
    db.table("transaction_tags").delete().eq("doc_number", doc).execute()
    if tag_ids:
        db.table("transaction_tags").insert([{"doc_number": doc, "tag_id": tid} for tid in tag_ids]).execute()
    return 200, {"ok": True}


def _create_tag(db, body):
    name = (body.get("name") or "").strip()
    if not name:
        return 400, {"error": "name wajib"}
    db.table("tags").upsert({"name": name, "emoji": body.get("emoji")}, on_conflict="name").execute()
    return 200, {"ok": True}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        res = get_client().table("tags").select("*").order("name").execute()
        send_json(self, 200, {"tags": res.data})

    def do_POST(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        body = read_json(self)
        if q.get("action") == "assign":
            status, resp = _assign_tags(db, body)
        else:
            status, resp = _create_tag(db, body)
        send_json(self, status, resp)

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
