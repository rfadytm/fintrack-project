"""ASCII sparkline (▁▂▃▄▅▆▇█) — dipakai laporan Telegram yang tidak bisa render gambar chart."""

_BLOCKS = "▁▂▃▄▅▆▇█"


def render(values: list[float]) -> str:
    """Ubah list angka jadi satu baris sparkline. String kosong kalau values kosong."""
    if not values:
        return ""
    lo, hi = min(values), max(values)
    if hi == lo:
        return _BLOCKS[0] * len(values)
    span = hi - lo
    return "".join(
        _BLOCKS[min(int((v - lo) / span * (len(_BLOCKS) - 1)), len(_BLOCKS) - 1)] for v in values
    )
