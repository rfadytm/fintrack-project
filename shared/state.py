"""bot_state management. B4: upsert atomik per-row (PK user_id) anti race condition."""
from datetime import datetime, timedelta, timezone

from shared.db import get_client

STATE_TIMEOUT_MINS = 30


def get_state(user_id: int) -> dict:
    res = (
        get_client().table("bot_state").select("*").eq("user_id", user_id).execute()
    )
    if not res.data:
        return {"user_id": user_id, "state": "IDLE", "state_data": {}}

    row = res.data[0]
    # Timeout -> reset IDLE
    updated = datetime.fromisoformat(row["updated_at"])
    if datetime.now(timezone.utc) - updated > timedelta(minutes=STATE_TIMEOUT_MINS):
        set_state(user_id, "IDLE", {})
        return {"user_id": user_id, "state": "IDLE", "state_data": {}}
    return row


def set_state(user_id: int, state: str, state_data: dict | None = None):
    get_client().table("bot_state").upsert(
        {
            "user_id": user_id,
            "state": state,
            "state_data": state_data or {},
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).execute()


def reset_state(user_id: int):
    set_state(user_id, "IDLE", {})
