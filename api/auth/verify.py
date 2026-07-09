"""POST /api/auth/verify — token magic-link -> session cookie 30 hari."""
from datetime import datetime, timezone
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.auth import create_session, session_cookie_header, verify_token_signature
from shared.db import get_client
from shared.http import read_json, send_json


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = read_json(self)
        token = body.get("token")
        if not token:
            return send_json(self, 400, {"error": "token wajib"})

        payload = verify_token_signature(token)
        if not payload:
            return send_json(self, 401, {"error": "token invalid / expired"})

        db = get_client()
        # Security fix: cek is_used dan tandai used dalam SATU UPDATE (bukan
        # SELECT lalu UPDATE terpisah). Versi lama punya celah TOCTOU — dua
        # request nyaris bersamaan dengan token yang sama bisa lolos SELECT
        # is_used=false sebelum salah satunya sempat UPDATE, menghasilkan 2
        # sesi dari 1 token single-use. WHERE is_used=false di UPDATE membuat
        # Postgres cuma meloloskan SATU request lewat row lock, request kedua
        # tidak akan match baris apa pun.
        upd = (
            db.table("auth_tokens")
            .update({"is_used": True, "used_at": datetime.now(timezone.utc).isoformat()})
            .eq("token", token)
            .eq("is_used", False)
            .execute()
        )
        if not upd.data:
            return send_json(self, 401, {"error": "token sudah dipakai / tidak ada"})

        row = upd.data[0]
        if datetime.fromisoformat(row["expires_at"]) < datetime.now(timezone.utc):
            return send_json(self, 401, {"error": "token expired"})

        cookie = session_cookie_header(create_session(payload["user_id"]))
        send_json(self, 200, {"logged_in": True}, extra_headers={"Set-Cookie": cookie})
