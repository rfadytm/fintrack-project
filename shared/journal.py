"""Posting jurnal double-entry via RPC post_document.

Dipakai API layer (POST /api/transactions) & pipeline OCR. RPC yang menegakkan
guard balance + period-lock (07_functions.sql) — helper ini hanya generate
doc-number atomik lalu memanggilnya.
"""
from datetime import date

from shared.db import get_client
from shared.doc_number import generate as gen_doc

_ALLOWED_SOURCES = {"telegram", "dashboard", "system"}


class JournalError(ValueError):
    pass


def _validate_lines(lines):
    if not isinstance(lines, list) or not lines:
        raise JournalError("lines wajib list non-kosong")
    for i, ln in enumerate(lines):
        if not isinstance(ln, dict) or not ln.get("account_code"):
            raise JournalError(f"lines[{i}]: account_code wajib")
        debit = int(ln.get("debit", 0) or 0)
        credit = int(ln.get("credit", 0) or 0)
        if debit < 0 or credit < 0:
            raise JournalError(f"lines[{i}]: debit/credit tidak boleh negatif")
        if (debit > 0) == (credit > 0):
            raise JournalError(f"lines[{i}]: isi salah satu debit ATAU credit (> 0)")


def post(doc_type: str, tx_date: date, description, lines, source: str = "system") -> str:
    """Post 1 dokumen. Return doc_number. Raise JournalError untuk input invalid.

    Balance & period-lock divalidasi di RPC post_document (bukan di sini).
    """
    if source not in _ALLOWED_SOURCES:
        source = "system"
    _validate_lines(lines)
    doc = gen_doc(doc_type, tx_date)  # gen_doc juga validasi doc_type
    norm = [
        {
            "account_code": ln["account_code"],
            "debit": int(ln.get("debit", 0) or 0),
            "credit": int(ln.get("credit", 0) or 0),
        }
        for ln in lines
    ]
    get_client().rpc(
        "post_document",
        {
            "p_doc_number": doc,
            "p_doc_type": doc_type,
            "p_date": tx_date.isoformat(),
            "p_description": description,
            "p_input_source": source,
            "p_is_reversal": False,
            "p_reversal_of": None,
            "p_lines": norm,
        },
    ).execute()
    return doc
