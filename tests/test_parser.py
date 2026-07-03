"""Offline tests parser OCR struk/nota (tanpa DB/OCR). Jalankan: python -m pytest tests/"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.receipt_parser import parse_receipt

INDOMARET = """INDOMARET 0231
JL MERDEKA NO 5
INDOMILK        12.000
ROTI TAWAR      15.500
AQUA 600ML       4.500
TOTAL           32.000
TUNAI           50.000
KEMBALI         18.000
03/07/2026 14:22
"""

WARUNG = """Warung Bu Sri
Nasi Goreng x2   30000
Es Teh x2        10000
Total Bayar      40000
02-07-26
"""

GOPAY = """GoPay
Pembayaran Berhasil
Rp 25.000
GoFood - Kopi Kenangan
3 Jul 2026, 09:15
"""


def test_indomaret_total_by_keyword():
    p = parse_receipt(INDOMARET)
    assert p["amount"] == 32000            # ambil TOTAL, bukan TUNAI 50.000
    assert p["date"] == "2026-07-03"
    assert p["merchant"] == "Indomaret"    # nomor cabang '0231' dibuang
    assert p["confidence"] == 100


def test_warung_plain_number():
    p = parse_receipt(WARUNG)
    assert p["amount"] == 40000            # angka polos tanpa pemisah ribuan
    assert p["date"] == "2026-07-02"       # DD-MM-YY
    assert p["confidence"] == 100


def test_gopay_textual_date():
    p = parse_receipt(GOPAY)
    assert p["amount"] == 25000
    assert p["date"] == "2026-07-03"       # '3 Jul 2026' → ISO
    assert p["merchant"] == "Gopay"


def test_ignores_kembalian():
    # 'KEMBALI 18.000' & 'TUNAI 50.000' tidak boleh jadi total.
    p = parse_receipt(INDOMARET)
    assert p["amount"] != 50000
    assert p["amount"] != 18000


def test_low_confidence_when_blurry():
    p = parse_receipt("??? blurry\nxxx\n")
    assert p["amount"] is None
    assert p["confidence"] < 50            # < ambang → bot minta input manual


def test_empty_text_safe():
    p = parse_receipt("")
    assert p["amount"] is None
    assert p["confidence"] == 0
