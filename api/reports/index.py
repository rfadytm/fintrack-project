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
from shared.forecast import holt_forecast, linear_forecast
from shared.http import get_query, paginate, require_session, send_json, session_or_public
from shared.masking import is_public, mask_amount, mask_number_list, mask_row, mask_rows
from shared.reports import month_totals, month_totals_from_rows


def _report_balance(db, q, viewer):
    query = db.table("account_balances").select("*")
    if q.get("type"):
        query = query.eq("account_type", q["type"])
    res = query.order("code").execute()
    balances = res.data
    if is_public(viewer):
        balances = mask_rows(balances, {"total_debit", "total_credit", "balance"})
    return 200, {"balances": balances}


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


def _report_monthly(db, q, viewer):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    summary = (
        db.table("monthly_summary").select("*").eq("period_year", year).eq("period_month", month).execute()
    )
    income, expense = month_totals_from_rows(summary.data)
    by_type = summary.data
    net = income - expense
    opening_balance = _opening_balance(db, year, month)
    # savings_rate sengaja TIDAK di-mask — rasio/persentase, bukan angka
    # rupiah absolut, jadi tetap informatif buat demo publik tanpa
    # membocorkan nominal (lihat diskusi masking di doc.txt).
    savings_rate = round((income - expense) / income, 4) if income > 0 else None
    if is_public(viewer):
        income, expense, net, opening_balance = (
            mask_amount(income), mask_amount(expense), mask_amount(net), mask_amount(opening_balance)
        )
        by_type = mask_rows(by_type, {"total_debit", "total_credit"})
    return 200, {
        "year": year,
        "month": month,
        "income": income,
        "expense": expense,
        "net": net,
        "opening_balance": opening_balance,
        "savings_rate": savings_rate,
        "by_type": by_type,
    }


def _report_ledger(db, q, viewer):
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
    if is_public(viewer):
        rows = mask_rows(rows, {"debit_amount", "credit_amount", "running_balance"})
    return 200, {"account": account, "lines": rows, "total": res.count}


def _report_trial_balance(db, q, viewer):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    res = db.rpc("trial_balance", {"p_year": year, "p_month": month}).execute()
    rows = res.data or []
    total_debit = sum(r["total_debit"] for r in rows)
    total_credit = sum(r["total_credit"] for r in rows)
    balanced = total_debit == total_credit
    accounts = rows
    if is_public(viewer):
        accounts = mask_rows(rows, {"total_debit", "total_credit", "balance"})
        total_debit, total_credit = mask_amount(total_debit), mask_amount(total_credit)
    return 200, {
        "year": year,
        "month": month,
        "accounts": accounts,
        "total_debit": total_debit,
        "total_credit": total_credit,
        "balanced": balanced,
    }


def _report_income_statement(db, q, viewer):
    if not q.get("year") or not q.get("month"):
        return 400, {"error": "year & month wajib"}
    year, month = int(q["year"]), int(q["month"])
    res = db.rpc("income_statement", {"p_year": year, "p_month": month}).execute()
    rows = res.data or []
    revenue = [r for r in rows if r["account_type"] == "pendapatan"]
    expense = [r for r in rows if r["account_type"] == "beban"]
    total_rev = sum(r["amount"] for r in revenue)
    total_exp = sum(r["amount"] for r in expense)
    net_income = total_rev - total_exp
    if is_public(viewer):
        revenue = mask_rows(revenue, {"amount"})
        expense = mask_rows(expense, {"amount"})
        total_rev, total_exp, net_income = mask_amount(total_rev), mask_amount(total_exp), mask_amount(net_income)
    return 200, {
        "year": year,
        "month": month,
        "revenue": revenue,
        "expense": expense,
        "total_revenue": total_rev,
        "total_expense": total_exp,
        "net_income": net_income,
    }


def _report_range(db, q, viewer):
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
    net_income = total_revenue - total_expense
    if is_public(viewer):
        revenue = mask_rows(revenue, {"amount"})
        expense = mask_rows(expense, {"amount"})
        total_revenue, total_expense, net_income = (
            mask_amount(total_revenue), mask_amount(total_expense), mask_amount(net_income)
        )
    return 200, {
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "revenue": revenue,
        "expense": expense,
        "total_revenue": total_revenue,
        "total_expense": total_expense,
        "net_income": net_income,
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


def _earliest_posted_period(db):
    """Bulan pertama yang benar-benar ada transaksi POSTED, atau None kalau
    belum ada transaksi sama sekali. Dipakai supaya forecast tidak menghitung
    mundur ke bulan SEBELUM user mulai pakai sistem — mem-padding bulan yang
    "belum eksis" dengan nol bikin winsorizing salah kira satu-satunya bulan
    asli sebagai outlier (user baru beberapa hari pakai -> forecast keliru
    tampil 0)."""
    res = (
        db.table("transactions")
        .select("period_year, period_month")
        .eq("status", "POSTED")
        .order("period_year")
        .order("period_month")
        .limit(1)
        .execute()
    )
    if not res.data:
        return None
    return res.data[0]["period_year"], res.data[0]["period_month"]


def _months_between(y1, m1, y2, m2):
    """Jumlah bulan kalender dari (y1,m1) s.d. (y2,m2) inklusif kedua ujung."""
    return (y2 * 12 + m2) - (y1 * 12 + m1) + 1


def _report_forecast(db, q, viewer):
    try:
        max_months = min(max(int(q.get("months", 6)), 2), 12)
    except ValueError:
        max_months = 6

    today = today_wib()
    last_complete_y, last_complete_m = _shift_month(today.year, today.month, -1)

    empty = {
        "months": 0,
        "real_months_available": 0,
        "income_history": [],
        "expense_history": [],
        "short_term": {"label": "1 bulan", "months": 1, "min_real_months": 1, "income": None, "expense": None},
        "medium_term": {
            "label": "1 kuartal (3 bulan)",
            "months": 3,
            "min_real_months": 2,
            "income": None,
            "expense": None,
        },
        "long_term": {
            "label": "1 tahun (12 bulan)",
            "months": 12,
            "min_real_months": 3,
            "income": None,
            "expense": None,
        },
        "top_categories": [],
    }

    earliest = _earliest_posted_period(db)
    if not earliest:
        return 200, empty

    # Forecast dibangun HANYA dari bulan yang sudah LENGKAP (bulan berjalan
    # yang belum selesai tidak dihitung — datanya belum final, membandingkan
    # bulan penuh vs bulan sebagian akan bikin tren keliru). Kalau bulan
    # pertama user pakai sistem = bulan ini juga (belum ada 1 bulan lengkap
    # pun), belum ada landasan sama sekali untuk forecast.
    real_available = _months_between(earliest[0], earliest[1], last_complete_y, last_complete_m)
    if real_available < 1:
        return 200, empty

    window = min(max_months, real_available)
    periods = [_shift_month(last_complete_y, last_complete_m, -i) for i in range(window - 1, -1, -1)]

    income_hist = [0] * window
    expense_hist = [0] * window
    category_hist = {}
    for i, (y, m) in enumerate(periods):
        income_hist[i], expense_hist[i] = month_totals(db, y, m)
        for code, row in _category_totals(db, y, m).items():
            entry = category_hist.setdefault(code, {"account_name": row["account_name"], "values": [0] * window})
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

    # Tiga horizon dari MODEL TREN YANG SAMA (bukan model terpisah per
    # horizon) — makin panjang horizon, makin banyak bulan lengkap yang
    # disyaratkan sebelum ditampilkan, karena mengekstrapolasi tren dari
    # sedikit titik makin jauh ke depan makin tidak reliable:
    #   jangka pendek (1 bulan)  -> butuh >=1 bulan lengkap (landasan minimal
    #                                yang disepakati user; 1 titik = flat carry-forward)
    #   jangka menengah (kuartal)-> butuh >=2 bulan lengkap (minimal ada arah tren)
    #   jangka panjang (tahun)   -> butuh >=3 bulan lengkap (tren sedikit lebih stabil
    #                                sebelum diekstrapolasi 12 bulan ke depan)
    def _sum_tier(steps, min_real_months, label):
        base = {"label": label, "months": steps, "min_real_months": min_real_months}
        if real_available < min_real_months:
            return {**base, "income": None, "expense": None}
        return {
            **base,
            "income": sum(holt_forecast(income_hist, steps)),
            "expense": sum(holt_forecast(expense_hist, steps)),
        }

    income_history, expense_history = income_hist, expense_hist
    short_term = _sum_tier(1, 1, "1 bulan")
    medium_term = _sum_tier(3, 2, "1 kuartal (3 bulan)")
    long_term = _sum_tier(12, 3, "1 tahun (12 bulan)")
    if is_public(viewer):
        income_history = mask_number_list(income_history)
        expense_history = mask_number_list(expense_history)
        short_term = {**short_term, "income": mask_amount(short_term["income"]), "expense": mask_amount(short_term["expense"])}
        medium_term = {**medium_term, "income": mask_amount(medium_term["income"]), "expense": mask_amount(medium_term["expense"])}
        long_term = {**long_term, "income": mask_amount(long_term["income"]), "expense": mask_amount(long_term["expense"])}
        # Re-sort alphabetically after masking, not just null the values —
        # the pre-mask list is order-by-real-forecast-descending, so
        # presentation order alone would still leak which expense category
        # is biggest/smallest even with every number replaced by None.
        top_categories = sorted(
            (
                {**c, "history": mask_number_list(c["history"]), "forecast": mask_amount(c["forecast"])}
                for c in top_categories
            ),
            key=lambda r: r["account_name"] or "",
        )
    return 200, {
        "months": window,
        "real_months_available": real_available,
        "income_history": income_history,
        "expense_history": expense_history,
        "short_term": short_term,
        "medium_term": medium_term,
        "long_term": long_term,
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
        viewer = session_or_public(self)
        q = get_query(self)
        name = q.get("report")
        fn = _REPORTS.get(name)
        if not fn:
            return send_json(self, 400, {"error": f"report tidak dikenal: {name!r}. Pilihan: {sorted(_REPORTS)}"})
        status, body = fn(get_client(), q, viewer)
        if status == 200:
            body["viewer"] = viewer["via"]
        send_json(self, status, body)
