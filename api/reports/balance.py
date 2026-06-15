"""GET /api/reports/balance — saldo semua akun via account_balances view."""
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, require_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        query = get_client().table("account_balances").select("*")
        if q.get("type"):
            query = query.eq("account_type", q["type"])
        res = query.order("code").execute()
        send_json(self, 200, {"balances": res.data})
