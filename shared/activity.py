"""Log aktivitas bot — backing store untuk 3 fitur sekaligus: rate limiting,
anti-abuse detection, dan activity logging umum. Lihat db/16_activity_log.sql.
"""
from datetime import datetime, timedelta, timezone

from shared.db import get_client
from shared.forecast import is_anomaly, threshold_for

_POST_ACTIONS = ("callback:exp_post", "callback:inc_post", "callback:tr_post")


def log(user_id: int, action: str, meta: dict | None = None) -> None:
    get_client().table("activity_log").insert(
        {"user_id": user_id, "action": action, "meta": meta or {}}
    ).execute()


def count_recent(user_id: int, seconds: int = 60) -> int:
    """Jumlah aktivitas user dalam N detik terakhir — dipakai rate limiting."""
    since = (datetime.now(timezone.utc) - timedelta(seconds=seconds)).isoformat()
    res = (
        get_client()
        .table("activity_log")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .gte("created_at", since)
        .execute()
    )
    return res.count or 0


def count_recent_posts(user_id: int, minutes: int = 60) -> int:
    """Jumlah transaksi berhasil di-posting user dalam N menit terakhir — deteksi bulk-add."""
    since = (datetime.now(timezone.utc) - timedelta(minutes=minutes)).isoformat()
    res = (
        get_client()
        .table("activity_log")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .in_("action", list(_POST_ACTIONS))
        .gte("created_at", since)
        .execute()
    )
    return res.count or 0


def flag_large_amount(amount: int, recent_amounts: list[int], sensitivity: str = "normal") -> bool:
    """True kalau `amount` menyimpang jauh (z-score) dari histori nominal serupa."""
    return is_anomaly(float(amount), [float(a) for a in recent_amounts], threshold_for(sensitivity))
