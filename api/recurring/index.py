"""GET/POST/DELETE /api/recurring?resource=recurring|bill — recurring transactions
& bills dalam SATU function (Vercel Hobby cap 12 Serverless Functions/deployment —
lihat catatan di api/reports/index.py). Semua request WAJIB sertakan
?resource=recurring atau ?resource=bill; frontend (src/utils/api.ts) yang menentukan.

resource=recurring:
  GET    — daftar transaksi berulang aktif
  POST   {"id"?,"doc_type","description","lines","frequency","next_run"?,"is_active"?}
  DELETE ?id= — nonaktifkan
resource=bill:
  GET    — daftar tagihan aktif
  POST   {"id"?,"name","amount","due_day"?,"due_date"?,"is_recurring"?}
  DELETE ?id= — nonaktifkan
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.format import today_wib
from shared.http import get_query, read_json, require_session, send_json

_DOC_TYPES = {"OB", "KK", "KM", "TR", "JU", "RV"}
_FREQUENCIES = {"daily", "weekly", "monthly"}


def _get_recurring(db):
    res = db.table("recurring_transactions").select("*").eq("is_active", True).order("next_run").execute()
    return 200, {"recurring": res.data}


def _post_recurring(db, body):
    doc_type = (body.get("doc_type") or "").upper()
    frequency = body.get("frequency")
    lines = body.get("lines")
    if doc_type not in _DOC_TYPES or frequency not in _FREQUENCIES or not lines:
        return 400, {"error": "doc_type, frequency (daily/weekly/monthly) & lines wajib"}
    row = {
        "doc_type": doc_type,
        "description": body.get("description"),
        "lines": lines,
        "frequency": frequency,
        "next_run": body.get("next_run") or today_wib().isoformat(),
        "is_active": body.get("is_active", True),
    }
    if body.get("id"):
        db.table("recurring_transactions").update(row).eq("id", body["id"]).execute()
    else:
        db.table("recurring_transactions").insert(row).execute()
    return 200, {"ok": True}


def _delete_recurring(db, q):
    if not q.get("id"):
        return 400, {"error": "id wajib"}
    db.table("recurring_transactions").update({"is_active": False}).eq("id", int(q["id"])).execute()
    return 200, {"ok": True}


def _get_bills(db):
    res = db.table("bills").select("*").eq("is_active", True).execute()
    return 200, {"bills": res.data}


def _post_bill(db, body):
    name = body.get("name")
    amount = body.get("amount")
    due_day = body.get("due_day")
    due_date = body.get("due_date")
    if not name or not isinstance(amount, (int, float)) or amount <= 0:
        return 400, {"error": "name & amount (>0) wajib"}
    if not due_day and not due_date:
        return 400, {"error": "due_day (1-31) atau due_date wajib"}
    row = {
        "name": name,
        "amount": int(amount),
        "due_day": due_day,
        "due_date": due_date,
        "is_recurring": body.get("is_recurring", True),
    }
    if body.get("id"):
        db.table("bills").update(row).eq("id", body["id"]).execute()
    else:
        db.table("bills").insert(row).execute()
    return 200, {"ok": True}


def _delete_bill(db, q):
    if not q.get("id"):
        return 400, {"error": "id wajib"}
    db.table("bills").update({"is_active": False}).eq("id", int(q["id"])).execute()
    return 200, {"ok": True}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        if q.get("resource") == "bill":
            status, body = _get_bills(db)
        else:
            status, body = _get_recurring(db)
        send_json(self, status, body)

    def do_POST(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        body = read_json(self)
        if q.get("resource") == "bill":
            status, resp = _post_bill(db, body)
        else:
            status, resp = _post_recurring(db, body)
        send_json(self, status, resp)

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        if q.get("resource") == "bill":
            status, resp = _delete_bill(db, q)
        else:
            status, resp = _delete_recurring(db, q)
        send_json(self, status, resp)
