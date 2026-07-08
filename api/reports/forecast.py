"""GET /api/reports/forecast?months=6 — proyeksi income/expense bulan depan (regresi
linear sederhana, shared/forecast.py) + top-5 kategori beban berdasarkan tren.
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.format import today_wib
from shared.forecast import linear_forecast
from shared.http import get_query, require_session, send_json


def _shift_month(year, month, delta):
    idx = (year * 12 + (month - 1)) + delta
    return idx // 12, idx % 12 + 1


def _month_totals(db, year, month):
    res = db.table("monthly_summary").select("*").eq("period_year", year).eq("period_month", month).execute()
    income = expense = 0
    for r in res.data:
        if r["account_type"] == "pendapatan":
            income += r["total_credit"] - r["total_debit"]
        elif r["account_type"] == "beban":
            expense += r["total_debit"] - r["total_credit"]
    return income, expense


def _category_totals(db, year, month):
    res = (
        db.table("journal_lines")
        .select(
            "account_code, debit_amount, chart_of_accounts(account_name, account_type), "
            "transactions!inner(period_year, period_month, status)"
        )
        .eq("transactions.period_year", year)
        .eq("transactions.period_month", month)
        .eq("transactions.status", "POSTED")
        .execute()
    )
    totals = {}
    for r in res.data:
        acc = r.get("chart_of_accounts") or {}
        if acc.get("account_type") != "beban":
            continue
        key = r["account_code"]
        row = totals.setdefault(key, {"account_name": acc.get("account_name"), "amount": 0})
        row["amount"] += r["debit_amount"] or 0
    return totals


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        try:
            months = min(max(int(q.get("months", 6)), 2), 12)
        except ValueError:
            months = 6

        db = get_client()
        today = today_wib()
        periods = [_shift_month(today.year, today.month, -i) for i in range(months - 1, -1, -1)]

        income_hist = [0] * months
        expense_hist = [0] * months
        category_hist = {}  # account_code -> {"account_name":..., "values": [0]*months}

        for i, (y, m) in enumerate(periods):
            income_hist[i], expense_hist[i] = _month_totals(db, y, m)
            for code, row in _category_totals(db, y, m).items():
                entry = category_hist.setdefault(code, {"account_name": row["account_name"], "values": [0] * months})
                entry["values"][i] = row["amount"]

        top_categories = sorted(
            (
                {
                    "code": code,
                    "account_name": entry["account_name"],
                    "history": entry["values"],
                    "forecast": linear_forecast(entry["values"]),
                }
                for code, entry in category_hist.items()
            ),
            key=lambda r: r["forecast"] or 0,
            reverse=True,
        )[:5]

        send_json(
            self,
            200,
            {
                "months": months,
                "income_history": income_hist,
                "expense_history": expense_hist,
                "income_forecast": linear_forecast(income_hist),
                "expense_forecast": linear_forecast(expense_hist),
                "top_categories": top_categories,
            },
        )
