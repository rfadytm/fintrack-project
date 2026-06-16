"""GET /api/auth/me — B5: cek session aktif untuk ProtectedRoute React."""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.http import current_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        sess = current_session(self)
        if sess:
            send_json(self, 200, {"logged_in": True, "user_id": sess["uid"]})
        else:
            send_json(self, 200, {"logged_in": False})

    def do_POST(self):
        # Logout: hapus cookie session.
        expired = "session=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0"
        send_json(self, 200, {"logged_in": False}, extra_headers={"Set-Cookie": expired})
