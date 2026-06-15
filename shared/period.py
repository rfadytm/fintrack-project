"""Period lock checker — dipanggil sebelum setiap POST transaksi."""
from datetime import date

from shared.db import get_client


class PeriodLockedError(Exception):
    pass


def is_locked(year: int, month: int) -> bool:
    res = (
        get_client()
        .table("periods")
        .select("is_locked")
        .eq("year", year)
        .eq("month", month)
        .execute()
    )
    if not res.data:
        return False
    return bool(res.data[0]["is_locked"])


def ensure_postable(tx_date: date) -> None:
    """Raise PeriodLockedError jika periode tx_date terkunci."""
    if is_locked(tx_date.year, tx_date.month):
        raise PeriodLockedError(
            f"Periode {tx_date.year}-{tx_date.month:02d} terkunci. Tidak bisa input/edit."
        )


def lock_period(year: int, month: int) -> None:
    from datetime import datetime, timezone

    get_client().table("periods").update(
        {"is_locked": True, "locked_at": datetime.now(timezone.utc).isoformat()}
    ).eq("year", year).eq("month", month).execute()
