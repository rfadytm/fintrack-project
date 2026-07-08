"""Offline tests untuk shared/scheduling.py (murni tanggal, tanpa DB). Jalankan: python -m pytest tests/"""
import os
import sys
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.scheduling import advance_next_run, bill_due_this_cycle, days_until, period_str


def test_advance_daily():
    assert advance_next_run(date(2026, 7, 8), "daily") == date(2026, 7, 9)


def test_advance_weekly():
    assert advance_next_run(date(2026, 7, 8), "weekly") == date(2026, 7, 15)


def test_advance_monthly_normal():
    assert advance_next_run(date(2026, 7, 8), "monthly") == date(2026, 8, 8)


def test_advance_monthly_clamps_short_month():
    # 31 Jan -> Februari cuma 28 hari (2026 bukan tahun kabisat) -> jatuh ke 28.
    assert advance_next_run(date(2026, 1, 31), "monthly") == date(2026, 2, 28)


def test_advance_monthly_year_rollover():
    assert advance_next_run(date(2026, 12, 15), "monthly") == date(2027, 1, 15)


def test_advance_unknown_frequency_raises():
    import pytest

    with pytest.raises(ValueError):
        advance_next_run(date(2026, 7, 8), "yearly")


def test_bill_due_this_cycle_future_this_month():
    # Hari ini tgl 8, jatuh tempo tgl 20 -> masih bulan ini.
    assert bill_due_this_cycle(20, date(2026, 7, 8)) == date(2026, 7, 20)


def test_bill_due_this_cycle_already_passed_rolls_to_next_month():
    # Hari ini tgl 25, jatuh tempo tgl 5 -> sudah lewat, jatuh ke bulan depan.
    assert bill_due_this_cycle(5, date(2026, 7, 25)) == date(2026, 8, 5)


def test_bill_due_this_cycle_due_day_beyond_month_length():
    # due_day=31 di bulan Februari -> clamp ke hari terakhir bulan itu.
    assert bill_due_this_cycle(31, date(2026, 2, 1)) == date(2026, 2, 28)


def test_days_until():
    assert days_until(date(2026, 7, 11), date(2026, 7, 8)) == 3
    assert days_until(date(2026, 7, 8), date(2026, 7, 8)) == 0
    assert days_until(date(2026, 7, 1), date(2026, 7, 8)) == -7


def test_period_str():
    assert period_str(date(2026, 7, 8)) == "2026-07"
    assert period_str(date(2027, 1, 1)) == "2027-01"
