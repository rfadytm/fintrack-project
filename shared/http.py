"""Helper untuk Vercel Python serverless (BaseHTTPRequestHandler)."""
import json
from urllib.parse import parse_qs, urlparse

from shared.auth import parse_cookie, verify_api_key, verify_session


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
