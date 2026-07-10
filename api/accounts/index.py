"""GET /api/accounts — daftar COA (filter: type, postable_only).
POST /api/accounts — tambah kategori beban custom (v3): {"account_name","account_type"?}.
Kode auto-pilih dari slot kosong 5940-5980 (grup 5900 — lihat db/15_custom_categories.sql).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import get_query, read_json, require_session, send_json, session_or_public

_VALID_TYPES = {"aset", "liabilitas", "ekuitas", "pendapatan", "beban"}
_NORMAL_BALANCE = {
    "aset": "debit",
    "beban": "debit",
    "liabilitas": "credit",
    "ekuitas": "credit",
    "pendapatan": "credit",
}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # chart_of_accounts has no amount/balance column (pure structure:
        # code, name, type, hierarchy) — safe to show publicly as-is, no
        # masking needed. Relaxed from require_session to session_or_public
        # so the portfolio's live-demo link can render the account list.
        viewer = session_or_public(self)
        q = get_query(self)
        query = get_client().table("chart_of_accounts").select("*").eq("is_active", True)
        if q.get("type"):
            query = query.eq("account_type", q["type"])
        if q.get("postable_only") == "true":
            query = query.eq("is_header", False)
        res = query.order("code").execute()
        send_json(self, 200, {"accounts": res.data, "viewer": viewer["via"]})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        name = (body.get("account_name") or "").strip()
        account_type = body.get("account_type", "beban")
        if not name:
            return send_json(self, 400, {"error": "account_name wajib"})
        if account_type not in _VALID_TYPES:
            return send_json(self, 400, {"error": f"account_type harus salah satu dari {sorted(_VALID_TYPES)}"})

        db = get_client()
        # v1: hanya kategori beban custom yang punya slot kosong siap pakai (grup 5900).
        # Tipe lain butuh keputusan penempatan kode manual — belum didukung dari sini.
        if account_type != "beban":
            return send_json(self, 400, {"error": "Saat ini hanya kategori beban yang bisa ditambah dari sini."})

        existing = db.table("chart_of_accounts").select("code").like("code", "59%").execute()
        used = {r["code"] for r in existing.data}
        code = next((str(c) for c in range(5940, 5990, 10) if str(c) not in used), None)
        if not code:
            return send_json(self, 400, {"error": "Slot kategori custom penuh."})

        db.table("chart_of_accounts").insert(
            {
                "code": code,
                "parent_code": "5900",
                "level": 3,
                "account_name": name,
                "account_type": "beban",
                "normal_balance": _NORMAL_BALANCE["beban"],
                "is_header": False,
                "is_active": True,
                "is_custom": True,
            }
        ).execute()
        send_json(self, 201, {"code": code})
