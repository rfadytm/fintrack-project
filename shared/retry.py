"""Retry generik dengan backoff pendek — cocok untuk Vercel serverless (batas waktu
eksekusi fungsi ketat, jadi backoff dalam detik bukan menit). Dipakai untuk panggilan
eksternal yang sesekali gagal transien (mis. shared/ocr.py).
"""
import time
from typing import Callable, TypeVar

T = TypeVar("T")


def retry(fn: Callable[[], T], attempts: int = 3, base_delay: float = 0.5) -> T:
    """Panggil fn() sampai `attempts` kali (delay antar percobaan naik 2x tiap gagal).

    Raise exception dari percobaan terakhir kalau semuanya gagal.
    """
    last_exc: Exception | None = None
    for i in range(attempts):
        try:
            return fn()
        except Exception as e:
            last_exc = e
            if i < attempts - 1:
                time.sleep(base_delay * (2**i))
    assert last_exc is not None
    raise last_exc
