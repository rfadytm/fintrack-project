# FinTrack — API Layer (base integrasi)

API HTTP FinTrack yang bisa dipakai **project lain** untuk membaca & menulis transaksi.
Tetap di Vercel Python serverless (same-origin dengan dashboard) — **tanpa** server terpisah.

## Base URL
- Produksi: `https://<app>.vercel.app`
- Semua path di bawah `/api/*`.

## Autentikasi
Dua cara:

| Cara | Header / mekanisme | Untuk |
|------|--------------------|-------|
| Session cookie | `Cookie: session=…` (httpOnly, di-set saat login dashboard) | Browser / dashboard |
| API key | `X-API-Key: <FINTRACK_API_KEY>` | **Project lain (server-to-server)** |

Set `FINTRACK_API_KEY` di env (lihat `.env.example`). Kalau kosong, auth API key nonaktif.
Endpoint OCR & create-transaction menerima **salah satu** dari keduanya (`require_auth`).
Endpoint read-only lama (list/report) masih **cookie-only** (`require_session`).

> ⚠️ Kirim `X-API-Key` hanya lewat HTTPS. Perlakukan seperti password.

## Endpoint

### `POST /api/transactions` — buat transaksi (double-entry)
Auth: cookie **atau** `X-API-Key`.

Body:
```json
{
  "doc_type": "KK",
  "date": "2026-07-03",
  "description": "Belanja Indomaret",
  "lines": [
    {"account_code": "5130", "debit": 45000, "credit": 0},
    {"account_code": "1130", "debit": 0,     "credit": 45000}
  ]
}
```
- `doc_type`: `OB|KK|KM|TR|JU|RV` (KK=pengeluaran, KM=pemasukan, TR=transfer, JU=jurnal umum).
- `date`: opsional, default hari ini (WIB).
- `lines`: minimal 2 baris, **total debit == total kredit** (dijaga RPC `post_document`).

Respons `201`: `{"doc_number": "KK-2026-07-001"}`
Error `400`: `{"error": "Tidak balance: debit … <> kredit …"}` / period terkunci / akun invalid.

```bash
curl -X POST https://<app>.vercel.app/api/transactions \
  -H "X-API-Key: $FINTRACK_API_KEY" -H "Content-Type: application/json" \
  -d '{"doc_type":"KK","description":"Kopi","lines":[
        {"account_code":"5120","debit":25000,"credit":0},
        {"account_code":"1130","debit":0,"credit":25000}]}'
```

### `POST /api/receipts/parse` — OCR struk/nota → field transaksi
Auth: cookie **atau** `X-API-Key`. **Tidak** langsung membukukan — mengembalikan hasil parse.

Body (salah satu sumber gambar):
```json
{"telegram_file_id": "AgAC..."}      // ambil dari Telegram servers
{"image_base64": "<base64 JPEG/PNG>"}// kirim gambar langsung
```
Respons `200`:
```json
{
  "receipt_id": 12,
  "parsed": {"merchant": "Indomaret", "amount": 45000, "date": "2026-07-03", "confidence": 100},
  "raw_ocr_text": "…"
}
```
Alur integrasi: `POST /receipts/parse` → cek `confidence` → `POST /transactions` untuk membukukan.

### `GET /api/transactions` — list transaksi (cookie-only, sudah ada di v1)
Query: `type, status, year, month, limit, offset`.

### `GET /api/reports/*` — laporan (cookie-only, sudah ada di v1)
`monthly | balance | ledger | trial-balance | income-statement`.

## Alur OCR via Telegram (bawaan bot)
Kirim **foto struk** ke bot → bot OCR → tampilkan konfirmasi (merchant/nominal/tanggal/kategori)
→ tekan **✅ Simpan** → pilih akun sumber → transaksi `KK` terbentuk & struk ter-link
(`receipts.doc_number`). Confidence < `receipt_min_confidence` (default 50) → bot minta input manual.

## Catatan gratis & privasi
- OCR: **OCR.space free tier** (25k req/bln, tanpa kartu). Gambar diproses di server OCR.space;
  provider bisa diganti via `OCR_API_URL`.
- Tetap 100% di Vercel Hobby + Supabase free — **tanpa** Railway/FastAPI (same-origin auth utuh).
