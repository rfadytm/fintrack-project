"""Custom HMAC auth (Flow 7).

- Token = HMAC-SHA256(AUTH_SECRET, "{user_id}:{nonce}:{exp}") + payload, base64url.
- Single-use: dicatat di tabel auth_tokens, di-mark is_used setelah verify.
- Session cookie = HMAC-signed, httpOnly + Secure + SameSite=Strict, 30 hari.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import time

AUTH_SECRET = os.environ["AUTH_SECRET"].encode()

# Machine-to-machine key untuk integrasi project lain (header X-API-Key).
# Opsional: kalau kosong, auth via API key dinonaktifkan (hanya session cookie yang jalan).
API_KEY = os.environ.get("FINTRACK_API_KEY", "")


def verify_api_key(provided: str | None) -> bool:
    """True kalau X-API-Key cocok. Selalu False bila key server belum di-set."""
    if not API_KEY or not provided:
        return False
    return hmac.compare_digest(provided, API_KEY)


def _b64e(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def _sign(msg: bytes) -> str:
    return _b64e(hmac.new(AUTH_SECRET, msg, hashlib.sha256).digest())


# ---------- Magic-link token (single use) ----------
def generate_token(user_id: int, expiry_mins: int = 60) -> tuple[str, int]:
    """Return (token, expires_at_epoch). Simpan token ke auth_tokens oleh caller."""
    exp = int(time.time()) + expiry_mins * 60
    nonce = secrets.token_hex(8)
    payload = f"{user_id}:{nonce}:{exp}"
    sig = _sign(payload.encode())
    token = f"{_b64e(payload.encode())}.{sig}"
    return token, exp


def verify_token_signature(token: str) -> dict | None:
    """Verifikasi signature + expiry (belum cek single-use; itu di DB)."""
    try:
        payload_b64, sig = token.split(".", 1)
        payload = _b64d(payload_b64).decode()
        if not hmac.compare_digest(sig, _sign(payload.encode())):
            return None
        user_id, nonce, exp = payload.split(":")
        if int(exp) < int(time.time()):
            return None
        return {"user_id": int(user_id), "exp": int(exp)}
    except Exception:
        return None


# ---------- Session cookie ----------
def create_session(user_id: int, days: int = 30) -> str:
    exp = int(time.time()) + days * 86400
    payload = json.dumps({"uid": user_id, "exp": exp}, separators=(",", ":"))
    body = _b64e(payload.encode())
    return f"{body}.{_sign(body.encode())}"


def verify_session(cookie: str | None) -> dict | None:
    if not cookie:
        return None
    try:
        body, sig = cookie.split(".", 1)
        if not hmac.compare_digest(sig, _sign(body.encode())):
            return None
        data = json.loads(_b64d(body))
        if data["exp"] < int(time.time()):
            return None
        return data
    except Exception:
        return None


def session_cookie_header(token: str, days: int = 30) -> str:
    max_age = days * 86400
    return (
        f"session={token}; HttpOnly; Secure; SameSite=Strict; "
        f"Path=/; Max-Age={max_age}"
    )


def parse_cookie(cookie_header: str | None, name: str = "session") -> str | None:
    if not cookie_header:
        return None
    for part in cookie_header.split(";"):
        k, _, v = part.strip().partition("=")
        if k == name:
            return v
    return None
