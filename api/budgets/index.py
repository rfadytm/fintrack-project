"""GET /api/budgets — daftar budget + spend bulan berjalan.
POST /api/budgets — buat/update budget: {"account_code","monthly_limit"}.
DELETE /api/budgets?account_code= — hapus budget.
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


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        db = get_client()
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
        send_json(self, 200, {"budgets": budgets})

    def do_POST(self):
        if not require_session(self):
            return
        body = read_json(self)
        code = body.get("account_code")
        limit = body.get("monthly_limit")
        if not code or not isinstance(limit, (int, float)) or limit <= 0:
            return send_json(self, 400, {"error": "account_code & monthly_limit (>0) wajib"})
        db = get_client()
        acc = db.table("chart_of_accounts").select("code").eq("code", code).eq("is_header", False).execute()
        if not acc.data:
            return send_json(self, 400, {"error": f"kode akun {code} tidak ditemukan/bukan postable"})
        db.table("budgets").upsert({"account_code": code, "monthly_limit": int(limit)}).execute()
        send_json(self, 200, {"ok": True})

    def do_DELETE(self):
        if not require_session(self):
            return
        q = get_query(self)
        code = q.get("account_code")
        if not code:
            return send_json(self, 400, {"error": "account_code wajib"})
        get_client().table("budgets").delete().eq("account_code", code).execute()
        send_json(self, 200, {"ok": True})
