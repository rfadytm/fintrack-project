"""POST /api/tags/assign — pasang/lepas tag pada satu transaksi.
Body: {"doc_number", "tag_ids": [1,2,...]} — replace total (bukan tambah incremental).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import read_json, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        doc = body.get("doc_number")
        tag_ids = body.get("tag_ids")
        if not doc or tag_ids is None:
            return send_json(self, 400, {"error": "doc_number & tag_ids wajib"})
        db = get_client()
        tx = db.table("transactions").select("doc_number").eq("doc_number", doc).execute()
        if not tx.data:
            return send_json(self, 400, {"error": f"dokumen {doc} tidak ditemukan"})
        db.table("transaction_tags").delete().eq("doc_number", doc).execute()
        if tag_ids:
            db.table("transaction_tags").insert(
                [{"doc_number": doc, "tag_id": tid} for tid in tag_ids]
            ).execute()
        send_json(self, 200, {"ok": True})
