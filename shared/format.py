"""Formatting helpers (IDR, tanggal WIB)."""
from datetime import datetime, timedelta, timezone

WIB = timezone(timedelta(hours=7))


def rupiah(amount: int) -> str:
    return "Rp " + f"{int(amount):,}".replace(",", ".")


def now_wib() -> datetime:
    return datetime.now(WIB)


def today_wib():
    return now_wib().date()


_BULAN = [
    "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember",
]


def bulan_nama(month: int) -> str:
    return _BULAN[month]


def fmt_date(d) -> str:
    if isinstance(d, str):
        d = datetime.fromisoformat(d).date()
    return f"{d.day} {bulan_nama(d.month)[:3]} {d.year}"
