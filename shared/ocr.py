"""OCR engine via OCR.space free API (raw httpx — konsisten gaya B7).

Kenapa OCR.space, bukan Tesseract lokal:
- Vercel Python serverless tidak bisa apt-install binary tesseract → packaging rapuh.
- OCR.space free tier: 25.000 request/bulan, TANPA kartu kredit. Return < ~10s → aman
  dari timeout serverless. Zero cost, zero binary.

Trade-off privasi: gambar struk dikirim ke server OCR.space untuk diproses.
Untuk pemakaian personal ini acceptable; provider bisa diganti lewat env OCR_API_URL.

Env:
- OCR_API_KEY  : API key gratis dari https://ocr.space/ocrapi ('helloworld' hanya untuk tes).
- OCR_API_URL  : default https://api.ocr.space/parse/image
- OCR_ENGINE   : default '2' (engine 2 lebih baik untuk struk).
"""
import os

import httpx

API_KEY = os.environ.get("OCR_API_KEY", "")
API_URL = os.environ.get("OCR_API_URL", "https://api.ocr.space/parse/image")
ENGINE = os.environ.get("OCR_ENGINE", "2")
# OCR.space free tier menolak file > ~1 MB. Guard di sini agar pesan errornya jelas
# (bukan error mentah dari API). Bisa dinaikkan via env kalau pakai paid tier.
MAX_BYTES = int(os.environ.get("OCR_MAX_BYTES", "1000000"))


class OCRError(RuntimeError):
    pass


def extract_text(image_bytes: bytes, filename: str = "receipt.jpg", timeout: int = 60) -> str:
    """Kirim gambar ke OCR.space, kembalikan raw text. Raise OCRError kalau gagal.

    Tidak meng-crash import kalau key kosong — error hanya muncul saat dipanggil,
    jadi endpoint/webhook lain tetap jalan meski OCR belum dikonfigurasi.
    """
    if not API_KEY:
        raise OCRError(
            "OCR belum dikonfigurasi. Set OCR_API_KEY (gratis di https://ocr.space/ocrapi)."
        )
    if len(image_bytes) > MAX_BYTES:
        raise OCRError(
            f"Gambar terlalu besar ({len(image_bytes) // 1024} KB, batas {MAX_BYTES // 1024} KB). "
            "Kirim sebagai FOTO (bukan file), atau kompres dulu."
        )

    data = {
        "apikey": API_KEY,
        "language": "eng",       # struk Indonesia mayoritas latin/angka → 'eng' cukup
        "OCREngine": ENGINE,
        "scale": "true",
        "isTable": "true",       # struk = layout tabel; bantu jaga urutan baris
        "detectOrientation": "true",
    }
    files = {"file": (filename, image_bytes)}

    try:
        r = httpx.post(API_URL, data=data, files=files, timeout=timeout)
        r.raise_for_status()
        payload = r.json()
    except httpx.HTTPError as e:
        raise OCRError(f"Gagal hubungi OCR service: {e}") from e
    except ValueError as e:
        raise OCRError("Respons OCR bukan JSON valid.") from e

    if payload.get("IsErroredOnProcessing"):
        msg = payload.get("ErrorMessage") or payload.get("ErrorDetails") or "unknown"
        if isinstance(msg, list):
            msg = "; ".join(msg)
        raise OCRError(f"OCR error: {msg}")

    results = payload.get("ParsedResults") or []
    if not results:
        raise OCRError("OCR tidak mengembalikan hasil.")

    return results[0].get("ParsedText", "") or ""
