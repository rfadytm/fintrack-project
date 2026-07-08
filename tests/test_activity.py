"""Offline tests untuk shared/activity.py — Supabase client di-mock sepenuhnya.
Jalankan: python -m pytest tests/
"""
import os
import sys
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# shared/db.py reads these once at import time. Set dummies just long enough to import
# (module caching means the read only happens once per process), then restore whatever
# was there before — leaving a dummy value behind in os.environ would trick test_db.py's
# `skipif(not os.environ.get("SUPABASE_URL"))` guard into thinking real creds are present
# and attempting a real connection (see conftest.py for the fuller explanation).
_had_url = "SUPABASE_URL" in os.environ
_had_key = "SUPABASE_SERVICE_KEY" in os.environ
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
try:
    from shared import activity
finally:
    if not _had_url:
        os.environ.pop("SUPABASE_URL", None)
    if not _had_key:
        os.environ.pop("SUPABASE_SERVICE_KEY", None)


def _mock_table(count=None, data=None):
    """Mock chainable Supabase query builder: table().select().eq()...execute()."""
    m = MagicMock()
    for method in ("select", "eq", "gte", "in_"):
        getattr(m, method).return_value = m
    result = MagicMock()
    result.data = data if data is not None else []
    result.count = count
    m.execute.return_value = result
    m.insert.return_value.execute.return_value = result
    return m


def test_count_recent_returns_query_count():
    client = MagicMock()
    client.table.return_value = _mock_table(count=3)
    with patch("shared.activity.get_client", return_value=client):
        assert activity.count_recent(123, seconds=60) == 3


def test_count_recent_zero_when_no_rows():
    client = MagicMock()
    client.table.return_value = _mock_table(count=None)
    with patch("shared.activity.get_client", return_value=client):
        assert activity.count_recent(123) == 0


def test_log_inserts_expected_row():
    client = MagicMock()
    table = _mock_table()
    client.table.return_value = table
    with patch("shared.activity.get_client", return_value=client):
        activity.log(123, "command:/saldo", {"x": 1})
    table.insert.assert_called_once_with({"user_id": 123, "action": "command:/saldo", "meta": {"x": 1}})


def test_log_defaults_empty_meta():
    client = MagicMock()
    table = _mock_table()
    client.table.return_value = table
    with patch("shared.activity.get_client", return_value=client):
        activity.log(123, "message")
    table.insert.assert_called_once_with({"user_id": 123, "action": "message", "meta": {}})


def test_count_recent_posts_filters_post_actions():
    client = MagicMock()
    table = _mock_table(count=2)
    client.table.return_value = table
    with patch("shared.activity.get_client", return_value=client):
        assert activity.count_recent_posts(123, minutes=60) == 2
    table.in_.assert_called_once()
    called_actions = table.in_.call_args[0][1]
    assert set(called_actions) == {"callback:exp_post", "callback:inc_post", "callback:tr_post"}


def test_flag_large_amount_true_for_outlier():
    history = [30000, 32000, 28000, 31000, 29500]
    assert activity.flag_large_amount(500000, history) is True


def test_flag_large_amount_false_for_typical_value():
    history = [30000, 32000, 28000, 31000, 29500]
    assert activity.flag_large_amount(31500, history) is False
