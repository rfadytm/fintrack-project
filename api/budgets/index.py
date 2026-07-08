"""GET/POST/DELETE /api/budgets?resource=budget|goal — budgets & goals dalam SATU
function (Vercel Hobby cap 12 Serverless Functions/deployment — lihat catatan di
api/reports/index.py). Semua request WAJIB sertakan ?resource=budget atau
?resource=goal; frontend (src/utils/api.ts) yang menentukan.

resource=budget:
  GET    — daftar budget + spend bulan berjalan
  POST   {"account_code","monthly_limit"} — buat/update
  DELETE ?account_code= — hapus
resource=goal:
  GET    — daftar goal + progress live (saldo account_code)
  POST   {"id"?,"name","target_amount","account_code","target_date"?} — buat/update
  DELETE ?id= — nonaktifkan (is_active=false)
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.format import today_wib
from shared.http import get_query, read_json, require_session, send_json


def _month_spend(db, account_code, year, month):
    res = (
        db.table("journal_lines")
        .select("debit_amount, transactions!inner(period_year, period_month, status)")
        .eq("account_code", account_code)
        .eq("transactions.period_year", year)
        .eq("transactions.period_month", month)
        .eq("transactions.status", "POSTED")
        .execute()
    )
    return sum(r["debit_amount"] or 0 for r in res.data)


def _get_budgets(db):
    res = (
        db.table("budgets")
        .select("account_code, monthly_limit, last_alert_at, chart_of_accounts(account_name)")
        .execute()
    )
    today = today_wib()
    budgets = []
    for row in res.data:
        spent = _month_spend(db, row["account_code"], today.year, today.month)
        budgets.append(
            {
                "account_code": row["account_code"],
                "account_name": (row.get("chart_of_accounts") or {}).get("account_name"),
                "monthly_limit": row["monthly_limit"],
                "spent": spent,
                "last_alert_at": row["last_alert_at"],
            }
        )
    return 200, {"budgets": budgets}


def _post_budget(db, body):
    code = body.get("account_code")
    limit = body.get("monthly_limit")
    if not code or not isinstance(limit, (int, float)) or limit <= 0:
        return 400, {"error": "account_code & monthly_limit (>0) wajib"}
    acc = db.table("chart_of_accounts").select("code").eq("code", code).eq("is_header", False).execute()
    if not acc.data:
        return 400, {"error": f"kode akun {code} tidak ditemukan/bukan postable"}
    db.table("budgets").upsert({"account_code": code, "monthly_limit": int(limit)}).execute()
    return 200, {"ok": True}


def _delete_budget(db, q):
    code = q.get("account_code")
    if not code:
        return 400, {"error": "account_code wajib"}
    db.table("budgets").delete().eq("account_code", code).execute()
    return 200, {"ok": True}


def _get_goals(db):
    res = db.table("goals").select("*").eq("is_active", True).execute()
    goals = []
    for g in res.data:
        current = 0
        if g.get("account_code"):
            bal = db.table("account_balances").select("balance").eq("code", g["account_code"]).execute()
            current = bal.data[0]["balance"] if bal.data else 0
        goals.append({**g, "current_amount": current})
    return 200, {"goals": goals}


def _post_goal(db, body):
    name = body.get("name")
    target = body.get("target_amount")
    if not name or not isinstance(target, (int, float)) or target <= 0:
        return 400, {"error": "name & target_amount (>0) wajib"}
    row = {
        "name": name,
        "target_amount": int(target),
        "account_code": body.get("account_code"),
        "target_date": body.get("target_date"),
    }
    if body.get("id"):
        db.table("goals").update(row).eq("id", body["id"]).execute()
    else:
        db.table("goals").insert(row).execute()
    return 200, {"ok": True}


def _delete_goal(db, q):
    if not q.get("id"):
        return 400, {"error": "id wajib"}
    db.table("goals").update({"is_active": False}).eq("id", int(q["id"])).execute()
    return 200, {"ok": True}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        if q.get("resource") == "goal":
            status, body = _get_goals(db)
        else:
            status, body = _get_budgets(db)
        send_json(self, status, body)

    def do_POST(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        body = read_json(self)
        if q.get("resource") == "goal":
            status, resp = _post_goal(db, body)
        else:
            status, resp = _post_budget(db, body)
        send_json(self, status, resp)

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        db = get_client()
        if q.get("resource") == "goal":
            status, resp = _delete_goal(db, q)
        else:
            status, resp = _delete_budget(db, q)
        send_json(self, status, resp)
