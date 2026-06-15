"""Smoke test koneksi Supabase. Butuh env terisi (skip jika tidak ada).

Jalankan: python -m pytest tests/test_db.py
"""
import os

import pytest

pytestmark = pytest.mark.skipif(
    not os.environ.get("SUPABASE_URL"), reason="SUPABASE_URL belum di-set"
)


def test_connection_and_coa():
    from shared.db import get_client

    res = get_client().table("chart_of_accounts").select("code").limit(1).execute()
    assert res.data is not None


def test_cash_accounts_exist():
    from shared.db import get_client

    res = (
        get_client().table("chart_of_accounts")
        .select("code")
        .in_("code", ["1110", "1120", "1130", "1140"])
        .execute()
    )
    codes = {r["code"] for r in res.data}
    assert {"1110", "1120", "1130", "1140"} <= codes
