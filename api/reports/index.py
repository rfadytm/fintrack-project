"""GET /api/reports?report=<name> — semua laporan dalam SATU function.

Konsolidasi dari 7 file terpisah (balance/monthly/ledger/trial-balance/
income-statement/range/forecast) jadi 1, karena Vercel Hobby plan cuma boleh
maksimal 12 Serverless Functions per deployment — proyek ini sudah pas di 12
sebelum v3, jadi endpoint baru WAJIB dikonsolidasi, bukan ditambah sebagai file
baru. Lihat docs/CHANGELOG_v2.md-style catatan di commit ini untuk detail.

?report=balance             (query: type?)
?report=monthly             (query: year, month wajib)
?report=ledger              (query: account wajib, year?, month?)
?report=trial-balance       (query: year, month wajib)
?report=income-statement    (query: year, month wajib)
?report=range               (query: date_from, date_to wajib)
?report=forecast            (query: months? default 6)
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from datetime import date
from http.server import BaseHTTPRequestHandler

from shared.db import get_client
from shared.format import today_wib
from shared.forecast import linear_forecast
from shared.http import get_query, paginate, require_session, send_json
from shared.reports import month_totals, month_totals_from_rows


def _report_balance(db, q):
    query = db.table("account_balances").select("*")
    if q.get("type"):
        query = query.eq("account_type", q["type"])
    res = query.order("code").execute()
    return 200, {"balances": res.data}


def _opening_balance(db, year, month):
    """Total saldo awal (/setup, doc OB) yang JATUH DI PERIODE INI, kalau ada.
    Modal awal (ekuitas 3110) BUKAN pendapatan secara akuntansi — ini dipisah
    supaya tidak ikut ke `income`/Laba Rugi, tapi tetap bisa ditampilkan sebagai
    catatan/pengecualian di dashboard (blindspot yang dilaporkan user: OB=0 di
    Pemasukan bikin bingung, padahal itu memang benar secara double-entry)."""
    ob = (
        db.table("transactions")
        .select("doc_number")
        .eq("doc_type", "OB")
        .eq("period_year", year)
        .eq("period_month", month)
        .eq("status", "POSTED")
        .execute()
    )
    if not ob.data:
        return None
    doc_numbers = [r["doc_number"] for r in ob.data]
    lines = db.table("journal_lines").select("debit_amount").in_("doc_number", doc_numbers).gt("debit_amount", 0).execute()
    total = sum(l["debit_amount"] or 0 for l in lines.data)
    return total or None


def _report_monthly(db, q):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    summary = (
        db.table("monthly_summary").select("*").eq("period_year", year).eq("period_month", month).execute()
    )
    income, expense = month_totals_from_rows(summary.data)
    return 200, {
        "year": year,
        "month": month,
        "income": income,
        "expense": expense,
        "net": income - expense,
        "opening_balance": _opening_balance(db, year, month),
        "savings_rate": round((income - expense) / income, 4) if income > 0 else None,
        "by_type": summary.data,
    }


def _report_ledger(db, q):
    account = q.get("account")
    if not account:
        return 400, {"error": "account wajib"}
    limit, offset = paginate(q, default_limit=100)

    # Blindspot fix: running_balance selalu dihitung debit-credit, benar untuk
    # akun normal debit (aset/beban) tapi TERBALIK untuk akun normal credit
    # (liabilitas/ekuitas/pendapatan) — Buku Besar untuk akun-akun itu jadi
    # salah tanda (mis. saldo utang kelihatan makin kecil padahal nambah).
    acc = db.table("chart_of_accounts").select("normal_balance").eq("code", account).execute()
    normal_balance = acc.data[0]["normal_balance"] if acc.data else "debit"

    query = (
        db.table("journal_lines")
        .select(
            "id, line_order, account_code, debit_amount, credit_amount, "
            "transactions!inner(doc_number, transaction_date, description, status, period_year, period_month)",
            count="exact",
        )
        .eq("account_code", account)
        .eq("transactions.status", "POSTED")
    )
    if q.get("year"):
        query = query.eq("transactions.period_year", int(q["year"]))
    if q.get("month"):
        query = query.eq("transactions.period_month", int(q["month"]))
    res = query.range(offset, offset + limit - 1).execute()
    rows = sorted(res.data, key=lambda r: r["transactions"]["transaction_date"])
    running = 0
    for r in rows:
        delta = r["debit_amount"] - r["credit_amount"]
        running += delta if normal_balance == "debit" else -delta
        r["running_balance"] = running
    return 200, {"account": account, "lines": rows, "total": res.count}


def _report_trial_balance(db, q):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    res = db.rpc("trial_balance", {"p_year": year, "p_month": month}).execute()
    rows = res.data or []
    total_debit = sum(r["total_debit"] for r in rows)
    total_credit = sum(r["total_credit"] for r in rows)
    return 200, {
        "year": year,
        "month": month,
        "accounts": rows,
        "total_debit": total_debit,
        "total_credit": total_credit,
        "balanced": total_debit == total_credit,
    }


def _report_income_statement(db, q):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    res = db.rpc("income_statement", {"p_year": year, "p_month": month}).execute()
    rows = res.data or []
    revenue = [r for r in rows if r["account_type"] == "pendapatan"]
    expense = [r for r in rows if r["account_type"] == "beban"]
    total_rev = sum(r["amount"] for r in revenue)
    total_exp = sum(r["amount"] for r in expense)
    return 200, {
        "year": year,
        "month": month,
        "revenue": revenue,
        "expense": expense,
        "total_revenue": total_rev,
        "total_expense": total_exp,
        "net_income": total_rev - total_exp,
    }


def _report_range(db, q):
    raw_from, raw_to = q.get("date_from"), q.get("date_to")
    if not raw_from or not raw_to:
        return 400, {"error": "date_from & date_to (YYYY-MM-DD) wajib"}
    try:
        date_from = date.fromisoformat(raw_from)
        date_to = date.fromisoformat(raw_to)
    except ValueError:
        return 400, {"error": "format tanggal harus YYYY-MM-DD"}
    if date_from > date_to:
        return 400, {"error": "date_from harus <= date_to"}

    res = (
        db.table("journal_lines")
        .select(
            "account_code, debit_amount, credit_amount, "
            "chart_of_accounts(account_name, account_type), "
            "transactions!inner(status, transaction_date)"
        )
        .eq("transactions.status", "POSTED")
        .gte("transactions.transaction_date", date_from.isoformat())
        .lte("transactions.transaction_date", date_to.isoformat())
        .execute()
    )
    by_account = {}
    for r in res.data:
        acc = r.get("chart_of_accounts") or {}
        acc_type = acc.get("account_type")
        if acc_type not in ("pendapatan", "beban"):
            continue
        key = r["account_code"]
        row = by_account.setdefault(
            key, {"code": key, "account_name": acc.get("account_name"), "account_type": acc_type, "amount": 0}
        )
        if acc_type == "pendapatan":
            row["amount"] += (r["credit_amount"] or 0) - (r["debit_amount"] or 0)
        else:
            row["amount"] += (r["debit_amount"] or 0) - (r["credit_amount"] or 0)
    revenue = [r for r in by_account.values() if r["account_type"] == "pendapatan"]
    expense = [r for r in by_account.values() if r["account_type"] == "beban"]
    total_revenue = sum(r["amount"] for r in revenue)
    total_expense = sum(r["amount"] for r in expense)
    return 200, {
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "revenue": revenue,
        "expense": expense,
        "total_revenue": total_revenue,
        "total_expense": total_expense,
        "net_income": total_revenue - total_expense,
    }


def _shift_month(year, month, delta):
    idx = (year * 12 + (month - 1)) + delta
    return idx // 12, idx % 12 + 1


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


def _report_forecast(db, q):
    try:
        months = min(max(int(q.get("months", 6)), 2), 12)
    except ValueError:
        months = 6
    today = today_wib()
    periods = [_shift_month(today.year, today.month, -i) for i in range(months - 1, -1, -1)]
    income_hist = [0] * months
    expense_hist = [0] * months
    category_hist = {}
    for i, (y, m) in enumerate(periods):
        income_hist[i], expense_hist[i] = month_totals(db, y, m)
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
    return 200, {
        "months": months,
        "income_history": income_hist,
        "expense_history": expense_hist,
        "income_forecast": linear_forecast(income_hist),
        "expense_forecast": linear_forecast(expense_hist),
        "top_categories": top_categories,
    }


_REPORTS = {
    "balance": _report_balance,
    "monthly": _report_monthly,
    "ledger": _report_ledger,
    "trial-balance": _report_trial_balance,
    "income-statement": _report_income_statement,
    "range": _report_range,
    "forecast": _report_forecast,
}


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not require_session(self):
            return
        q = get_query(self)
        name = q.get("report")
        fn = _REPORTS.get(name)
        if not fn:
            return send_json(self, 400, {"error": f"report tidak dikenal: {name!r}. Pilihan: {sorted(_REPORTS)}"})
        status, body = fn(get_client(), q)
        send_json(self, status, body)
