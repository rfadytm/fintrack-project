"""GET /api/auth/me — B5: cek session aktif untuk ProtectedRoute React."""
from http.server import BaseHTTPRequestHandler

from shared.http import current_session, send_json


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        sess = current_session(self)
        if sess:
            send_json(self, 200, {"logged_in": True, "user_id": sess["uid"]})
        else:
            send_json(self, 200, {"logged_in": False})
