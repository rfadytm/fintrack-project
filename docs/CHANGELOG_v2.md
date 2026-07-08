# FinTrack v2 — OCR Struk + API Layer (Changelog & Catatan Serah-Terima)

Tanggal: 2026-07-03 · Status: **live di produksi** (`https://fintrack-project-mu.vercel.app`)

Ringkasan perubahan v2 dan hal-hal yang perlu diketahui untuk maintenance.

---

## 1. Apa yang ditambahkan
Dua hal, keduanya **aditif** — tidak ada fitur v1 yang diubah/dihapus:
- **Input transaksi dari foto struk/nota** lewat bot Telegram (OCR).
- **API layer** (`POST /api/transactions` & `/api/receipts/parse`) sebagai fondasi integrasi dengan project lain.

## 2. Keputusan arsitektur terpenting
Proposal awal (`FinTrack_v2_Enhancement_Proposal.txt`) meminta migrasi ke **FastAPI + Railway**. **Ditolak**, tetap di Vercel serverless. Alasan:
- Railway **tidak gratis lagi** (free tier dihapus sejak 2023) → langgar syarat "harus gratis".
- Backend pindah domain → **cookie auth `SameSite=Strict` v1 patah** → dashboard tak bisa login.

Hasil: semua tetap **satu domain Vercel (same-origin)**, auth v1 utuh, **100% gratis**.

## 3. Cara kerja OCR (alur user)
```
Foto/File struk → bot OCR (OCR.space) → parse (merchant/nominal/tanggal)
→ kartu konfirmasi → ✅ Simpan → pilih akun sumber → transaksi KK tercatat
```
Perilaku yang perlu diingat:
- **Selalu dibukukan sebagai pengeluaran (`KK`)**. Screenshot pemasukan/transfer tidak otomatis — pakai menu manual.
- **Tanggal transaksi = hari ini (WIB), bukan tanggal di struk.** Tanggal struk hanya disimpan sebagai referensi di tabel `receipts` (hindari bentrok period-lock).
- **Confidence < 50% → bot minta input manual.** Loop konfirmasi = pengaman terakhir sebelum data masuk DB.
- Struk bisa dikirim sebagai **foto** atau **file/PDF**; **caption** foto menjadi keterangan transaksi.

## 4. API layer (integrasi)
- Auth: **cookie** (browser) **atau** header **`X-API-Key`** (server-to-server).
- Aktif hanya jika env `FINTRACK_API_KEY` diisi (default **kosong = nonaktif**).
- Dokumentasi + contoh `curl`: [`docs/API.md`](API.md).

## 5. Peta file

### Baru
| File | Fungsi |
|------|--------|
| `db/11_receipts.sql` | Tabel `receipts` + RLS + seed alias merchant/e-wallet + settings |
| `shared/ocr.py` | Klien OCR.space (via httpx) + guard ukuran |
| `shared/receipt_parser.py` | Parser regex: merchant/nominal/tanggal + confidence (pure) |
| `shared/journal.py` | Helper posting double-entry (dipakai API) |
| `api/receipts/parse.py` | Endpoint OCR (`POST /api/receipts/parse`) |
| `docs/API.md` | Dokumentasi API layer |
| `tests/test_parser.py` | 6 test parser |

### Diedit (aditif)
| File | Perubahan |
|------|-----------|
| `api/telegram/webhook.py` | Handle foto & file/PDF, tombol menu 🧾 Scan, command `/scan`, callback `rcp:*`, link receipt saat posting |
| `api/transactions/index.py` | Tambah `POST` (buat transaksi) di samping `GET` |
| `shared/telegram.py` | `download_file()` (getFile + download, raw httpx) |
| `shared/auth.py` | `verify_api_key()` |
| `shared/http.py` | `require_auth()` (cookie atau X-API-Key) |
| `.env.example`, `README.md`, `scripts/set_commands.py` | Config & docs, daftar `/scan` |

## 6. Konfigurasi & tombol setel
**Env (di Vercel):**
- `OCR_API_KEY` — key OCR.space (✅ sudah diset).
- `OCR_API_URL` — default `https://api.ocr.space/parse/image`.
- `OCR_ENGINE` — default `2` (akurasi lebih baik untuk struk).
- `OCR_MAX_BYTES` — default `1000000` (~1MB, batas free tier).
- `FINTRACK_API_KEY` — opsional; isi untuk mengaktifkan auth API-key.

**Di DB (`bot_settings`) — ubah tanpa deploy ulang:**
- `receipt_min_confidence` (default `50`) — ambang minimal bot menawarkan simpan.
- `receipt_default_expense` (default `9999`) — akun beban fallback bila merchant tak dikenali.

**Mapping merchant → kategori:** tabel `bot_aliases` (mis. `indomaret→5130`). Tambah merchant baru = tambah baris, tanpa ubah kode. Pencocokan memakai **alias terpanjang lebih dulu** (`grabfood` menang atas `grab`).

## 7. Biaya & limit
- **OCR.space free:** 25.000 request/bulan, file **≤ ~1MB**. Foto Telegram biasa aman; file besar/PDF → bot minta versi lebih kecil (pesan jelas, bukan error mentah).
- Vercel Hobby + Supabase free — tidak berubah.
- ⚠️ **Privasi:** gambar struk dikirim ke server OCR.space untuk diproses. Ganti provider via `OCR_API_URL` bila perlu.

## 8. Keamanan
- Tabel `receipts` kena **RLS** (backend pakai service_role/BYPASSRLS; publik ditolak).
- API-key dibandingkan dengan `hmac.compare_digest`; env kosong → jalur API-key mati total.
- **TODO:** rotate Supabase secret key, DB password, dan key OCR yang sempat lewat chat.

## 9. Blindspot yang sudah diperbaiki
| # | Blindspot | Solusi |
|---|-----------|--------|
| B1 | Struk dikirim sebagai File/Document → diabaikan | Handle `document` (image/* & PDF) |
| B2 | Limit ~1MB OCR.space tak dijaga | Guard `OCR_MAX_BYTES` + pilih PhotoSize di bawah limit |
| B3 | `rcp:save` tak defend amount None | Cek eksplisit → minta input manual |
| B4 | Caption foto diabaikan | Kolom `receipts.note` → jadi keterangan |
| B5 | `int(chat_id)` bisa crash | try/except default 0 |
| B6 | Alias substring salah kategori | Alias terpanjang menang |

## 10. Batasan yang diketahui (belum dikerjakan)
- Belum ada **dedup** retry webhook Telegram (risiko kecil; bot balas 200 < 60 dtk).
- **Anomaly detection / scheduled report / NLQ / life plan** dari proposal **belum** dibuat (bukan prioritas; sebagian butuh ≥3 bulan data).
- Akurasi OCR struk fisik nyata (font kasir/foto buram) perlu diuji end-to-end di HP; loop konfirmasi menahan data salah.

## 11. Verifikasi yang sudah dilakukan
- `py_compile` semua file · parser 6/6 test lulus.
- **Live OCR** dengan key asli: struk Indomaret → merchant `Indomaret`, amount `32000` (benar ambil TOTAL, abaikan TUNAI/KEMBALI), tanggal `2026-07-03`, confidence `100`.
- **Smoke test produksi** pasca-deploy: `/api/receipts/parse` & `POST /api/transactions` → `401` (hidup & auth-gated), bukan lagi 404/501.

## 12. Data mengalir ke mana
- **`receipts`** — staging hasil OCR (status `pending`/`confirmed`/`rejected`/`manual`), menyimpan `raw_ocr_text`, hasil parse, `note`, dan `doc_number` setelah dibukukan.
- **`transactions` + `journal_lines`** — catatan akuntansi final (via RPC `post_document`, double-entry + period-lock guard).

## 13. Automasi lanjutan: kenapa bukan n8n
Untuk kebutuhan otomasi masa depan (notifikasi terjadwal, pipeline OCR tambahan, reminder, dsb.) — **n8n sengaja tidak dipakai**. Alasan sama dengan penolakan Railway/FastAPI di §2: konsisten dengan prinsip "tetap 100% gratis, tanpa infra baru, jangan patahkan auth same-origin".
- n8n butuh **host terpisah** (self-hosted server/VPS, atau cloud n8n yang berbayar di luar free tier terbatas) → biaya & satu titik gagal baru, di luar Vercel+Supabase yang sudah ada.
- Semua kebutuhan "workflow otomatis" yang muncul sejauh ini (keepalive, backup harian) sudah tercakup oleh **GitHub Actions cron** (`.github/workflows/`, lihat README §Otomasi) + **Vercel serverless functions** — tanpa biaya tambahan, tanpa domain baru, tanpa auth ekstra.
- Kalau nanti ada kebutuhan automasi yang lebih kompleks dari cron sederhana (mis. multi-step retry, orkestrasi lintas layanan), opsi pertama tetap: tambah **Vercel Cron** (native, gratis di Hobby untuk jadwal harian) atau perluas GitHub Actions — **bukan** menambah layanan orkestrasi terpisah seperti n8n.
