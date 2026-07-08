"""Helper tanggal murni (tanpa DB) untuk recurring transactions & bill reminders —
dipisah dari api/cron/*.py supaya bisa di-unit-test tanpa mock Supabase.
"""
from datetime import date, timedelta


def advance_next_run(next_run: date, frequency: str) -> date:
    """Hitung next_run berikutnya setelah dieksekusi hari ini."""
    if frequency == "daily":
        return next_run + timedelta(days=1)
    if frequency == "weekly":
        return next_run + timedelta(days=7)
    if frequency == "monthly":
        # Tanggal sama bulan depan; kalau bulan depan lebih pendek (mis. tgl 31 -> Feb),
        # jatuh ke hari terakhir bulan itu.
        year = next_run.year + (1 if next_run.month == 12 else 0)
        month = 1 if next_run.month == 12 else next_run.month + 1
        day = min(next_run.day, _days_in_month(year, month))
        return date(year, month, day)
    raise ValueError(f"frequency tidak dikenal: {frequency}")


def _days_in_month(year: int, month: int) -> int:
    next_month = date(year + (1 if month == 12 else 0), 1 if month == 12 else month + 1, 1)
    return (next_month - timedelta(days=1)).day


def bill_due_this_cycle(due_day: int, today: date) -> date:
    """Tanggal jatuh tempo TERDEKAT (bisa bulan ini kalau belum lewat, atau bulan depan)."""
    day = min(due_day, _days_in_month(today.year, today.month))
    this_month = date(today.year, today.month, day)
    if this_month >= today:
        return this_month
    year = today.year + (1 if today.month == 12 else 0)
    month = 1 if today.month == 12 else today.month + 1
    day = min(due_day, _days_in_month(year, month))
    return date(year, month, day)


def days_until(target: date, today: date) -> int:
    return (target - today).days


def period_str(d: date) -> str:
    return f"{d.year:04d}-{d.month:02d}"
