"""GET /api/cron/housekeeping — dipanggil GitHub Actions tiap 30 menit.
Auth: header X-Cron-Secret.

Melengkapi Flow Timeout Protection (shared/state.py sudah auto-reset ke IDLE saat
get_state() dipanggil setelah >30 menit, tapi itu PASIF — user baru tahu kalau
kirim pesan lagi). Ini bagian PROAKTIF: sapu bot_state yang sudah stale & non-IDLE,
notify user, lalu reset — supaya user tahu flow yang tertunda sudah dibatalkan
tanpa perlu ngetik apa pun dulu.
"""
import os
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler

from shared import telegram as tg
from shared.db import get_client
from shared.http import require_cron, send_json

STATE_TIMEOUT_MINS = 30


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_cron(self):
            return
        db = get_client()
        cutoff = (datetime.now(timezone.utc) - timedelta(minutes=STATE_TIMEOUT_MINS)).isoformat()
        stale = (
            db.table("bot_state")
            .select("user_id, state, updated_at")
            .neq("state", "IDLE")
            .lt("updated_at", cutoff)
            .execute()
        )
        for row in stale.data:
            db.table("bot_state").update({"state": "IDLE", "state_data": {}}).eq(
                "user_id", row["user_id"]
            ).execute()
            try:
                tg.send_message(
                    row["user_id"],
                    "⏳ Input yang belum selesai (>30 menit tanpa aktivitas) sudah dibatalkan otomatis. Ketik /menu untuk mulai lagi.",
                )
            except Exception:
                pass  # notify best-effort; reset state tetap harus jalan
        send_json(self, 200, {"swept": len(stale.data)})
