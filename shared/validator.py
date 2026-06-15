"""Amount parsing (Bagian 6.3) + helper validasi.

Contoh: 25000, 25.000, 25,000, 25k, 25rb -> 25000 ; 25jt -> 25_000_000 ; 2,5jt -> 2_500_000
"""
import re

_SUFFIX = {
    "k": 1_000,
    "rb": 1_000,
    "ribu": 1_000,
    "jt": 1_000_000,
    "juta": 1_000_000,
    "m": 1_000_000,
}


class AmountError(ValueError):
    pass


def parse_amount(text: str) -> int:
    """Parse input nominal user -> int rupiah bulat. Raise AmountError jika invalid."""
    if text is None:
        raise AmountError("Format tidak valid. Contoh: 25000 atau 25k")
    s = text.strip().lower().replace(" ", "")

    m = re.fullmatch(r"([0-9]+(?:[.,][0-9]+)?)(k|rb|ribu|jt|juta|m)?", s)
    if not m:
        # mungkin format ribuan "25.000" / "25,000"
        digits = re.fullmatch(r"[0-9][0-9.,]*", s)
        if not digits:
            raise AmountError("Format tidak valid. Contoh: 25000 atau 25k")
        val = int(re.sub(r"[.,]", "", s))
    else:
        num_part, suffix = m.group(1), m.group(2)
        if suffix:
            # desimal hanya bermakna dengan suffix (2,5jt). Normalisasi koma -> titik.
            num = float(num_part.replace(",", "."))
            val = int(round(num * _SUFFIX[suffix]))
        else:
            # tanpa suffix: titik/koma = pemisah ribuan
            val = int(re.sub(r"[.,]", "", num_part))

    if val <= 0:
        raise AmountError("Nominal harus > 0")
    return val
