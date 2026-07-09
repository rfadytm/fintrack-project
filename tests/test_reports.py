"""Offline tests untuk shared/reports.py & api/reports/index.py (Supabase di-mock).
Cover blindspot fixes: ledger running_balance sign untuk akun normal credit, dan
_opening_balance (saldo awal /setup dipisah dari income/Laba Rugi).

Jalankan: python -m pytest tests/
"""
import os
import sys
from datetime import date
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# See test_activity.py for why these are set-then-restored rather than left in os.environ.
_had_url = "SUPABASE_URL" in os.environ
_had_key = "SUPABASE_SERVICE_KEY" in os.environ
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
try:
    from api.reports import index as reports_index
    from shared import reports
finally:
    if not _had_url:
        os.environ.pop("SUPABASE_URL", None)
    if not _had_key:
        os.environ.pop("SUPABASE_SERVICE_KEY", None)


def _mock_table(**overrides):
    """Mock chainable Supabase query builder: table().select().eq()...execute()."""
    m = MagicMock()
    for method in ("select", "eq", "gt", "in_", "order", "range", "limit"):
        getattr(m, method).return_value = m
    result = MagicMock()
    result.data = overrides.get("data", [])
    result.count = overrides.get("count")
    m.execute.return_value = result
    return m


def test_month_totals_from_rows_aggregates_income_and_expense():
    rows = [
        {"account_type": "pendapatan", "total_credit": 100, "total_debit": 10},
        {"account_type": "beban", "total_debit": 40, "total_credit": 0},
        {"account_type": "aset", "total_debit": 999, "total_credit": 0},  # diabaikan
    ]
    income, expense = reports.month_totals_from_rows(rows)
    assert income == 90
    assert expense == 40


def test_month_totals_queries_monthly_summary():
    client = MagicMock()
    table = _mock_table(data=[{"account_type": "pendapatan", "total_credit": 50, "total_debit": 0}])
    client.table.return_value = table
    income, expense = reports.month_totals(client, 2026, 7)
    assert income == 50
    assert expense == 0
    table.eq.assert_any_call("period_year", 2026)
    table.eq.assert_any_call("period_month", 7)


def test_report_ledger_running_balance_debit_normal_account():
    """Aset (normal debit): balance naik saat debit > credit, seperti biasa."""
    client = MagicMock()
    coa_table = _mock_table(data=[{"normal_balance": "debit"}])
    lines_table = _mock_table(
        data=[
            {
                "debit_amount": 100,
                "credit_amount": 0,
                "transactions": {"transaction_date": "2026-07-01"},
            },
            {
                "debit_amount": 0,
                "credit_amount": 30,
                "transactions": {"transaction_date": "2026-07-02"},
            },
        ],
        count=2,
    )

    def table_router(name):
        return coa_table if name == "chart_of_accounts" else lines_table

    client.table.side_effect = table_router
    status, body = reports_index._report_ledger(client, {"account": "1110"})
    assert status == 200
    assert [r["running_balance"] for r in body["lines"]] == [100, 70]


def test_report_ledger_running_balance_credit_normal_account():
    """Blindspot fix: liabilitas/ekuitas/pendapatan normal credit — balance harus
    naik saat credit > debit, bukan terbalik (bug lama: selalu debit - credit)."""
    client = MagicMock()
    coa_table = _mock_table(data=[{"normal_balance": "credit"}])
    lines_table = _mock_table(
        data=[
            {
                "debit_amount": 0,
                "credit_amount": 200,
                "transactions": {"transaction_date": "2026-07-01"},
            },
            {
                "debit_amount": 50,
                "credit_amount": 0,
                "transactions": {"transaction_date": "2026-07-02"},
            },
        ],
        count=2,
    )

    def table_router(name):
        return coa_table if name == "chart_of_accounts" else lines_table

    client.table.side_effect = table_router
    status, body = reports_index._report_ledger(client, {"account": "2110"})
    assert status == 200
    assert [r["running_balance"] for r in body["lines"]] == [200, 150]


def test_report_ledger_selects_account_code():
    """Blindspot fix: the select() list omitted account_code entirely, so every
    /api/reports?report=ledger response was missing that field. The frontend's
    JournalLineSchema requires account_code (non-optional) — its absence made
    Zod reject EVERY ledger response, surfacing as "Data dari server tidak
    sesuai format yang diharapkan" on the Buku Besar page for every account."""
    client = MagicMock()
    coa_table = _mock_table(data=[{"normal_balance": "debit"}])
    lines_table = _mock_table(data=[], count=0)

    def table_router(name):
        return coa_table if name == "chart_of_accounts" else lines_table

    client.table.side_effect = table_router
    reports_index._report_ledger(client, {"account": "1110"})
    select_arg = lines_table.select.call_args[0][0]
    assert "account_code" in select_arg


def test_opening_balance_none_when_no_ob_this_period():
    client = MagicMock()
    client.table.return_value = _mock_table(data=[])
    assert reports_index._opening_balance(client, 2026, 7) is None


def test_opening_balance_sums_ob_debit_lines():
    client = MagicMock()
    ob_table = _mock_table(data=[{"doc_number": "OB-0001"}])
    lines_table = _mock_table(data=[{"debit_amount": 500000}, {"debit_amount": 1000000}])

    def table_router(name):
        return ob_table if name == "transactions" else lines_table

    client.table.side_effect = table_router
    assert reports_index._opening_balance(client, 2026, 7) == 1500000


def _forecast_client(earliest_year, earliest_month):
    """DB client stub for _report_forecast: transactions -> a single earliest
    POSTED period; monthly_summary -> a flat 100 income every period (exact
    trend values aren't the point here, only whether tiers are locked);
    journal_lines -> no category breakdown."""
    tx_table = _mock_table(data=[{"period_year": earliest_year, "period_month": earliest_month}])
    summary_table = _mock_table(data=[{"account_type": "pendapatan", "total_credit": 100, "total_debit": 0}])
    lines_table = _mock_table(data=[])

    def router(name):
        return {"transactions": tx_table, "monthly_summary": summary_table, "journal_lines": lines_table}[name]

    client = MagicMock()
    client.table.side_effect = router
    return client


def test_forecast_no_transactions_ever_returns_all_tiers_locked():
    client = _forecast_client(2026, 7)
    tx_table = client.table("transactions")
    tx_table.execute.return_value.data = []  # belum ada transaksi sama sekali
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {})
    assert status == 200
    assert body["real_months_available"] == 0
    assert body["short_term"]["income"] is None
    assert body["medium_term"]["income"] is None
    assert body["long_term"]["income"] is None


def test_forecast_started_this_month_has_zero_complete_months():
    """Blindspot fix (dilaporkan user): user baru mulai BULAN INI (belum ada
    1 bulan lengkap sekalipun) — dulu forecast diam-diam menunjukkan 0 yang
    menyesatkan (bukan karena benar-benar 0, tapi karena bulan-bulan sebelum
    user mulai di-padding nol dan winsorizing salah kira 1 titik asli sebagai
    outlier). Sekarang harus eksplisit None (belum cukup data), bukan 0."""
    client = _forecast_client(2026, 7)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {})
    assert status == 200
    assert body["real_months_available"] == 0
    assert body["short_term"]["income"] is None


def test_forecast_one_complete_month_unlocks_short_term_only():
    # earliest = Juni 2026, "hari ini" = 9 Juli 2026 -> bulan lengkap: Juni saja.
    client = _forecast_client(2026, 6)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {})
    assert status == 200
    assert body["real_months_available"] == 1
    assert body["short_term"]["income"] is not None
    assert body["medium_term"]["income"] is None
    assert body["long_term"]["income"] is None


def test_forecast_two_complete_months_unlocks_medium_term():
    # earliest = Mei 2026 -> bulan lengkap: Mei, Juni.
    client = _forecast_client(2026, 5)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {})
    assert body["real_months_available"] == 2
    assert body["short_term"]["income"] is not None
    assert body["medium_term"]["income"] is not None
    assert body["long_term"]["income"] is None


def test_forecast_three_complete_months_unlocks_long_term():
    # earliest = Apr 2026 -> bulan lengkap: Apr, Mei, Juni.
    client = _forecast_client(2026, 4)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {})
    assert body["real_months_available"] == 3
    assert body["short_term"]["income"] is not None
    assert body["medium_term"]["income"] is not None
    assert body["long_term"]["income"] is not None


def test_forecast_window_never_pads_before_real_start():
    """Blindspot fix inti: window histori TIDAK BOLEH menghitung mundur ke
    bulan sebelum user mulai pakai sistem, walau `months` yang diminta lebih
    besar dari itu (default 6)."""
    # earliest = Jun 2026 (1 bulan lengkap: Juni), diminta months=6 (default).
    client = _forecast_client(2026, 6)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {"months": "6"})
    assert body["months"] == 1  # bukan 6 — dipangkas ke jumlah bulan asli yang tersedia
    assert len(body["income_history"]) == 1
