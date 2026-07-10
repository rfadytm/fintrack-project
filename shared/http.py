"""Helper untuk Vercel Python serverless (BaseHTTPRequestHandler)."""
import json
from urllib.parse import parse_qs, urlparse

from shared.auth import parse_cookie, verify_api_key, verify_cron_secret, verify_session


def send_json(handler, status: int, obj, extra_headers: dict | None = None):
    body = json.dumps(obj, default=str).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    if extra_headers:
        for k, v in extra_headers.items():
            handler.send_header(k, v)
    handler.end_headers()
    handler.wfile.write(body)


def get_query(handler) -> dict:
    qs = urlparse(handler.path).query
    return {k: v[0] for k, v in parse_qs(qs).items()}


def read_body(handler) -> bytes:
    length = int(handler.headers.get("Content-Length", 0) or 0)
    return handler.rfile.read(length) if length else b""


def read_json(handler) -> dict:
    raw = read_body(handler)
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def current_session(handler) -> dict | None:
    cookie = parse_cookie(handler.headers.get("Cookie"))
    return verify_session(cookie)


def require_session(handler) -> dict | None:
    """Return session, atau kirim 401 dan return None."""
    sess = current_session(handler)
    if not sess:
        send_json(handler, 401, {"error": "unauthorized"})
        return None
    return sess


def session_or_public(handler) -> dict:
    """Seperti require_session, tapi TIDAK PERNAH kirim 401 — dipakai khusus
    endpoint GET yang boleh diliat publik dalam bentuk ter-mask (demo di
    portfolio). Selalu return dict, tidak pernah None:
      - session asli kalau cookie valid: {"via": "session", "uid": ..., "exp": ...}
      - {"via": "public"} kalau tidak ada session valid

    JANGAN pakai ini untuk endpoint POST/PUT/DELETE — mutasi data tetap
    wajib require_session/require_auth yang menolak tegas dengan 401.
    Caller WAJIB mask field sensitif sendiri saat via == "public"; helper
    ini cuma menentukan mode, bukan melakukan masking-nya (lihat
    shared/masking.py)."""
    sess = current_session(handler)
    if sess:
        return {"via": "session", **sess}
    return {"via": "public"}


def require_auth(handler) -> dict | None:
    """Auth untuk endpoint yang boleh dipakai browser (cookie) ATAU project lain (X-API-Key).

    Return identitas {"via": "session"|"api_key", ...} atau kirim 401 dan return None.
    Dipakai endpoint integrasi (mis. POST /api/transactions, /api/receipts/parse).
    """
    sess = current_session(handler)
    if sess:
        return {"via": "session", **sess}
    if verify_api_key(handler.headers.get("X-API-Key")):
        return {"via": "api_key"}
    send_json(handler, 401, {"error": "unauthorized"})
    return None


def require_cron(handler) -> bool:
    """Auth untuk endpoint api/cron/* — dipanggil GitHub Actions, bukan browser.

    Return True, atau kirim 401 dan return False.
    """
    if verify_cron_secret(handler.headers.get("X-Cron-Secret")):
        return True
    send_json(handler, 401, {"error": "unauthorized"})
    return False


def paginate(query: dict, default_limit: int = 50, max_limit: int = 200):
    """B13: pagination dari awal. Return (limit, offset)."""
    try:
        limit = min(int(query.get("limit", default_limit)), max_limit)
    except ValueError:
        limit = default_limit
    try:
        offset = max(int(query.get("offset", 0)), 0)
    except ValueError:
        offset = 0
    return limit, offset
