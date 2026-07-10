"""Offline tests untuk shared/masking.py + integrasinya di api/reports/index.py
saat viewer publik (demo live di portfolio, tanpa session valid).

Masking pakai None, BUKAN string sentinel semacam "***" — lihat docstring
shared/masking.py untuk alasannya (string lolos ke aritmatika di frontend
dan bisa merusak data secara diam-diam, mis. concat string di JS).

Jalankan: python -m pytest tests/
"""
import os
import sys
from datetime import date
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

_had_url = "SUPABASE_URL" in os.environ
_had_key = "SUPABASE_SERVICE_KEY" in os.environ
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
try:
    from api.reports import index as reports_index
    from shared.masking import is_public, mask_amount, mask_number_list, mask_row, mask_rows
finally:
    if not _had_url:
        os.environ.pop("SUPABASE_URL", None)
    if not _had_key:
        os.environ.pop("SUPABASE_SERVICE_KEY", None)


PUBLIC = {"via": "public"}
OWNER = {"via": "session", "uid": 1}


def _mock_table(**overrides):
    m = MagicMock()
    for method in ("select", "eq", "gt", "in_", "order", "range", "limit"):
        getattr(m, method).return_value = m
    result = MagicMock()
    result.data = overrides.get("data", [])
    result.count = overrides.get("count")
    m.execute.return_value = result
    return m


# ---------- shared/masking.py primitives ----------


def test_mask_amount_always_returns_none():
    assert mask_amount(5_000_000) is None
    assert mask_amount(0) is None
    assert mask_amount(None) is None


def test_mask_number_list_returns_all_none_same_length():
    result = mask_number_list([1000, None, 2000])
    assert result == [None, None, None]
    assert len(result) == 3


def test_mask_row_replaces_in_place_and_does_not_mutate_original():
    row = {"account_code": "1130", "debit_amount": 45000, "credit_amount": 0}
    masked = mask_row(row, {"debit_amount", "credit_amount"})
    assert masked == {"account_code": "1130", "debit_amount": None, "credit_amount": None}
    assert row["debit_amount"] == 45000, "mask_row must not mutate the input row"


def test_mask_row_leaves_missing_fields_alone():
    row = {"code": "A"}
    assert mask_row(row, {"amount"}) == {"code": "A"}


def test_mask_rows_on_a_list():
    rows = [{"amount": 100, "code": "A"}, {"amount": 200, "code": "B"}]
    masked = mask_rows(rows, {"amount"})
    assert [r["amount"] for r in masked] == [None, None]
    assert [r["code"] for r in masked] == ["A", "B"]


def test_is_public():
    assert is_public(PUBLIC) is True
    assert is_public(OWNER) is False


# ---------- integration: _report_ledger ----------


def _ledger_client(normal_balance="debit"):
    coa_table = _mock_table(data=[{"normal_balance": normal_balance}])
    lines_table = _mock_table(
        data=[
            {"debit_amount": 100, "credit_amount": 0, "transactions": {"transaction_date": "2026-07-01"}},
        ],
        count=1,
    )
    client = MagicMock()
    client.table.side_effect = lambda name: coa_table if name == "chart_of_accounts" else lines_table
    return client


def test_report_ledger_masks_amounts_for_public_viewer():
    client = _ledger_client()
    status, body = reports_index._report_ledger(client, {"account": "1110"}, PUBLIC)
    assert status == 200
    line = body["lines"][0]
    assert line["debit_amount"] is None
    assert line["credit_amount"] is None
    assert line["running_balance"] is None
    # account is a code, not money — must survive untouched
    assert body["account"] == "1110"


def test_report_ledger_shows_real_amounts_for_owner():
    client = _ledger_client()
    status, body = reports_index._report_ledger(client, {"account": "1110"}, OWNER)
    assert status == 200
    line = body["lines"][0]
    assert line["debit_amount"] == 100
    assert line["running_balance"] == 100


# ---------- integration: _report_monthly ----------


def _monthly_client():
    summary_table = _mock_table(data=[{"account_type": "pendapatan", "total_credit": 500, "total_debit": 0}])
    ob_table = _mock_table(data=[])  # no opening balance this period
    client = MagicMock()
    client.table.side_effect = lambda name: summary_table if name == "monthly_summary" else ob_table
    return client


def test_report_monthly_masks_amounts_but_keeps_savings_rate_visible():
    """savings_rate is a ratio, not an absolute Rupiah figure — deliberately
    left unmasked (see doc.txt masking discussion). If this starts failing
    because savings_rate got masked too, that's a scope change, not a bug —
    update this test deliberately, don't just silence it."""
    client = _monthly_client()
    status, body = reports_index._report_monthly(client, {"year": "2026", "month": "7"}, PUBLIC)
    assert status == 200
    assert body["income"] is None
    assert body["expense"] is None
    assert body["net"] is None
    assert body["savings_rate"] is not None


def test_report_monthly_masks_nested_by_type_rows():
    client = _monthly_client()
    status, body = reports_index._report_monthly(client, {"year": "2026", "month": "7"}, PUBLIC)
    assert body["by_type"][0]["total_credit"] is None
    assert body["by_type"][0]["account_type"] == "pendapatan"  # non-sensitive, untouched


# ---------- integration: _report_forecast ----------


def _forecast_client(earliest_year, earliest_month):
    tx_table = _mock_table(data=[{"period_year": earliest_year, "period_month": earliest_month}])
    summary_table = _mock_table(data=[{"account_type": "pendapatan", "total_credit": 100, "total_debit": 0}])
    lines_table = _mock_table(data=[])
    client = MagicMock()
    client.table.side_effect = lambda name: {
        "transactions": tx_table, "monthly_summary": summary_table, "journal_lines": lines_table,
    }[name]
    return client


def test_report_forecast_masks_history_and_unlocked_tier_for_public_viewer():
    client = _forecast_client(2026, 6)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {}, PUBLIC)
    assert status == 200
    assert all(v is None for v in body["income_history"])
    assert body["short_term"]["income"] is None
    # structural fields (labels, month counts) are not money — untouched
    assert body["short_term"]["label"] == "1 bulan"
    assert body["real_months_available"] == 1


def test_report_forecast_owner_sees_real_unlocked_tier_value():
    """Companion to the public test above — confirms masking is genuinely
    viewer-conditional (owner still gets the real computed forecast), not
    that _report_forecast always returns None regardless of viewer."""
    client = _forecast_client(2026, 6)
    with patch.object(reports_index, "today_wib", return_value=date(2026, 7, 9)):
        status, body = reports_index._report_forecast(client, {}, OWNER)
    assert status == 200
    assert body["short_term"]["income"] is not None
    assert body["income_history"][0] is not None


# ---------- integration: _report_balance ----------


def test_report_balance_masks_totals_for_public_viewer():
    client = MagicMock()
    client.table.return_value = _mock_table(
        data=[{"code": "1110", "account_name": "Kas", "total_debit": 900, "total_credit": 200, "balance": 700}]
    )
    status, body = reports_index._report_balance(client, {}, PUBLIC)
    assert status == 200
    row = body["balances"][0]
    assert row["balance"] is None
    assert row["total_debit"] is None
    assert row["account_name"] == "Kas"  # not money — untouched


def test_report_balance_shows_real_totals_for_owner():
    client = MagicMock()
    client.table.return_value = _mock_table(
        data=[{"code": "1110", "account_name": "Kas", "total_debit": 900, "total_credit": 200, "balance": 700}]
    )
    status, body = reports_index._report_balance(client, {}, OWNER)
    assert body["balances"][0]["balance"] == 700
