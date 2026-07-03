"""Parser hasil OCR struk/nota → {merchant, amount, date, confidence}.

Rule-based (regex), sengaja pure & tanpa DB supaya gampang di-test (tests/test_parser.py).
Mapping merchant → akun COA dilakukan di caller (butuh query bot_aliases).

Prinsip: parser boleh salah — confidence + confirmation loop di bot adalah
last line of defense sebelum data masuk Supabase.
"""
import re
from datetime import date

# Kata kunci baris "total bayar" pada struk Indonesia (urut prioritas).
_TOTAL_KEYWORDS = (
    "grand total",
    "total bayar",
    "total belanja",
    "total tagihan",
    "total harga",
    "jumlah bayar",
    "total",
    "tagihan",
    "jumlah",
    "bayar",
)

# Kata yang menandakan baris BUKAN total (hindari salah ambil).
_NEGATIVE_KEYWORDS = ("kembali", "kembalian", "tunai", "cash", "change", "npwp", "no.")


def _money_to_int(token: str):
    """'Rp 45.000' / '45,000' / '1.234.567' / '12.500,00' -> int rupiah bulat, atau None."""
    t = re.sub(r"[^\d.,]", "", token)
    if not t:
        return None
    # Buang sen di akhir (',00' / '.00') bila ada pemisah ribuan sebelumnya.
    if re.search(r"[.,]\d{2}$", t) and re.search(r"\d[.,]\d{3}", t):
        t = t[:-3]
    digits = re.sub(r"[.,]", "", t)
    return int(digits) if digits.isdigit() and len(digits) <= 12 else None


# Ketat: butuh pemisah ribuan atau prefix 'Rp' → aman untuk scan seluruh struk
# (tidak salah tangkap nomor toko/qty). Longgar: + angka polos ≥ 3 digit → hanya
# dipakai di baris yang sudah jelas "total" (mis. nota warung 'Total Bayar 40000').
_MONEY_STRICT = re.compile(r"(?:rp\.?\s*)?\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\brp\.?\s*\d{3,}\b", re.I)
_MONEY_LOOSE = re.compile(
    r"(?:rp\.?\s*)?\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\brp\.?\s*\d{3,}\b|\b\d{3,}\b", re.I
)


def _money_in(line, pattern):
    return [v for v in (_money_to_int(m.group()) for m in pattern.finditer(line)) if v]


def _extract_amount(lines):
    """Return (amount, found_by_keyword). Prioritas baris ber-kata-kunci total."""
    best_kw = None
    for ln in lines:
        low = ln.lower()
        if any(neg in low for neg in _NEGATIVE_KEYWORDS):
            continue
        if any(kw in low for kw in _TOTAL_KEYWORDS):
            vals = _money_in(ln, _MONEY_LOOSE)
            if vals:
                cand = max(vals)
                if best_kw is None or cand > best_kw:
                    best_kw = cand
    if best_kw is not None:
        return best_kw, True

    # Fallback: nominal terbesar di seluruh struk (total biasanya paling besar).
    all_vals = []
    for ln in lines:
        low = ln.lower()
        if any(neg in low for neg in _NEGATIVE_KEYWORDS):
            continue
        all_vals += _money_in(ln, _MONEY_STRICT)
    if all_vals:
        return max(all_vals), False
    return None, False


_DATE_RE = re.compile(r"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b")

# Tanggal teks (e-wallet: 'GoPay', 'OVO' pakai '3 Jul 2026' / '3 Juli 2026').
_MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "mei": 5, "may": 5, "jun": 6,
    "jul": 7, "agu": 8, "aug": 8, "agt": 8, "sep": 9, "okt": 10, "oct": 10,
    "nov": 11, "des": 12, "dec": 12,
}
_DATE_TEXT_RE = re.compile(r"\b(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{4})\b")


def _mk_date(y, mth, d):
    if y < 100:
        y += 2000
    if not (1 <= mth <= 12 and 1 <= d <= 31 and 2000 <= y <= 2100):
        return None
    try:
        return date(y, mth, d).isoformat()
    except ValueError:
        return None


def _extract_date(text):
    """DD/MM/YYYY | DD-MM-YY | '3 Jul 2026' -> ISO 'YYYY-MM-DD', atau None."""
    for m in _DATE_RE.finditer(text):
        d, mth, y = (int(g) for g in m.groups())
        iso = _mk_date(y, mth, d)
        if iso:
            return iso
    for m in _DATE_TEXT_RE.finditer(text):
        d = int(m.group(1))
        mth = _MONTHS.get(m.group(2)[:3].lower())
        y = int(m.group(3))
        if mth:
            iso = _mk_date(y, mth, d)
            if iso:
                return iso
    return None


def _extract_merchant(lines):
    """Nama merchant = baris teks pertama yang 'namanya' (huruf dominan, bukan angka/alamat)."""
    for ln in lines[:6]:
        s = ln.strip()
        letters = sum(c.isalpha() for c in s)
        if len(s) >= 3 and letters >= 3 and letters >= len(s) * 0.5:
            # buang nomor toko/cabang di belakang: 'INDOMARET 0123' -> 'Indomaret'
            s = re.sub(r"\s+\d{2,}.*$", "", s).strip()
            return s.title()[:100] or None
    return None


def parse_receipt(raw_text: str) -> dict:
    """Parse raw OCR text. Return dict siap simpan ke tabel receipts.

    confidence: 0-100. Amount lewat kata kunci total = paling dipercaya.
    """
    lines = [ln for ln in (raw_text or "").splitlines() if ln.strip()]

    amount, by_keyword = _extract_amount(lines)
    tx_date = _extract_date(raw_text or "")
    merchant = _extract_merchant(lines)

    confidence = 0
    if amount:
        confidence += 50 if by_keyword else 25
    if tx_date:
        confidence += 25
    if merchant:
        confidence += 25
    confidence = min(confidence, 100)

    return {
        "merchant": merchant,
        "amount": amount,
        "date": tx_date,             # ISO string atau None
        "confidence": confidence,
        "by_keyword": by_keyword,
    }
