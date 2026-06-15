"""GET /api/accounts — daftar COA (filter: type, postable_only)."""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        query = get_client().table("chart_of_accounts").select("*").eq("is_active", True)
        if q.get("type"):
            query = query.eq("account_type", q["type"])
        if q.get("postable_only") == "true":
            query = query.eq("is_header", False)
        res = query.order("code").execute()
        send_json(self, 200, {"accounts": res.data})
