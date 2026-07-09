"""Offline tests untuk api/cron/index.py (Supabase & journal.post di-mock).
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
    from api.cron import index as cron
finally:
    if not _had_url:
        os.environ.pop("SUPABASE_URL", None)
    if not _had_key:
        os.environ.pop("SUPABASE_SERVICE_KEY", None)


def _mock_table(data=None):
    m = MagicMock()
    for method in ("select", "eq", "lte", "update"):
        getattr(m, method).return_value = m
    result = MagicMock()
    result.data = data if data is not None else []
    m.execute.return_value = result
    return m


def test_execute_recurring_advances_from_scheduled_date_not_today():
    """Blindspot fix: kalau cron telat (mis. GitHub Actions scheduled workflow
    molor lewat tengah malam), next_run harus tetap dihitung dari tanggal yang
    TERJADWAL (r["next_run"]), bukan dari `today` saat cron kebetulan jalan —
    kalau tidak, jangkar tanggal recurring bergeser maju permanen tiap kali telat."""
    row = {
        "id": 1,
        "doc_type": "KK",
        "description": "Langganan Netflix",
        "lines": [{"account_code": "5820", "debit": 54000, "credit": 0}],
        "frequency": "monthly",
        "next_run": "2026-07-05",  # dijadwalkan tgl 5, tapi cron baru jalan tgl 8 (telat 3 hari)
    }
    due_table = _mock_table(data=[row])
    db = MagicMock()
    db.table.return_value = due_table
    update_calls = []
    due_table.update.side_effect = lambda payload: update_calls.append(payload) or due_table

    with patch.object(cron, "OWNER_ID", 12345), patch.object(
        cron.journal, "post", return_value="KK-0001"
    ) as post, patch.object(cron.tg, "send_message"):
        cron._execute_recurring(db, date(2026, 7, 8))

    post.assert_called_once()
    assert update_calls == [{"next_run": "2026-08-05"}]  # tetap tgl 5, BUKAN 2026-08-08


def test_execute_recurring_reports_failure_without_crashing():
    row = {
        "id": 2,
        "doc_type": "KK",
        "description": "Gagal",
        "lines": [{"account_code": "5820", "debit": 10000, "credit": 0}],
        "frequency": "daily",
        "next_run": "2026-07-08",
    }
    due_table = _mock_table(data=[row])
    db = MagicMock()
    db.table.return_value = due_table
    sent = []

    with patch.object(cron, "OWNER_ID", 12345), patch.object(
        cron.journal, "post", side_effect=RuntimeError("periode terkunci")
    ), patch.object(cron.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append(text)):
        cron._execute_recurring(db, date(2026, 7, 8))

    assert any("gagal diposting" in t for t in sent)
