"""GET /api/settings — baca bot_settings. POST /api/settings — ubah (whitelist)."""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.http import read_json, require_session, send_json

# Hanya key ini yang boleh diubah dari dashboard.
EDITABLE = {
    "default_expense_source",
    "default_income_dest",
    "kas_kecil_source",
    "savings_account",
    "kas_kecil_target",
    "bi_fast_fee",
    # v3 preferences (db/17_v3_preferences.sql)
    "currency_preference",
    "timezone",
    "daily_report_enabled",
    "weekly_report_enabled",
    "alert_sensitivity",
    "rate_limit_per_minute",
    "budget_alert_throttle_mins",
}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        res = get_client().table("bot_settings").select("key, value, notes").execute()
        send_json(self, 200, {"settings": res.data, "editable": sorted(EDITABLE)})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        updates = body.get("settings", {})
        db = get_client()
        applied = {}
        for k, v in updates.items():
            if k in EDITABLE:
                db.table("bot_settings").update({"value": str(v)}).eq("key", k).execute()
                applied[k] = str(v)
        send_json(self, 200, {"updated": applied})
