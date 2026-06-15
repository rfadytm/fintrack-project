"""Auto-generate doc number: TYPE-YYYY-MM-NNN (mis. KK-2026-06-001).

Sequence di-increment atomik via RPC next_doc_seq (anti race condition).
"""
from datetime import date

from shared.db import get_client

VALID_TYPES = {"OB", "KK", "KM", "TR", "JU", "RV"}


def generate(doc_type: str, tx_date: date) -> str:
    if doc_type not in VALID_TYPES:
        raise ValueError(f"doc_type tidak valid: {doc_type}")
    res = get_client().rpc(
        "next_doc_seq",
        {"p_doc_type": doc_type, "p_year": tx_date.year, "p_month": tx_date.month},
    ).execute()
    seq = res.data
    return f"{doc_type}-{tx_date.year}-{tx_date.month:02d}-{seq:03d}"
