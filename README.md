# FinTrack — Personal Accounting System

Sistem akuntansi personal **double-entry** berbasis cloud: **Telegram Bot** (input) + **React dashboard** (monitoring) + **Supabase** (PostgreSQL) + **Vercel** (serverless, free tier).

## Arsitektur

```
Telegram ──▶ /api/telegram/webhook (Python) ──▶ Supabase
Browser  ──▶ /api/* (Python)                ──▶ Supabase ──▶ React SPA
```

Frontend & backend **terpisah** (folder `src/` vs `api/`+`shared/`) tapi deploy ke **satu domain Vercel** → same-origin, tanpa CORS, cookie auth httpOnly mulus.

## Struktur

| Folder | Isi |
|--------|-----|
| `api/` | Vercel serverless Python (bot webhook, REST API, auth) |
| `shared/` | Util Python dipakai semua `api/` (db, auth, doc_number, validator, period, telegram, state) |
| `db/` | SQL migrations `01`→`11` (jalankan berurutan; `11` = tabel `receipts` OCR) |
| `src/` | React + Vite (dashboard) |
| `scripts/` | setup_webhook, setup_db, backup_db, ngrok |
| `.github/workflows/` | keepalive (B8) + backup harian (B9) |

## Quick Start

1. `cp .env.example .env` lalu isi semua nilai.
2. Buat project Supabase, jalankan `db/01..10` di SQL Editor (atau `python scripts/migrate.py`).
3. `npm install` lalu `npm run dev` untuk frontend.
4. Deploy ke Vercel, set env vars, lalu `python scripts/setup_webhook.py https://<app>.vercel.app`.
5. Di Telegram: `/start` → `/setup` (saldo awal) → mulai input.

Detail lengkap di **[DEPLOY.md](DEPLOY.md)**. Referensi command di **[CHEATSHEET.md](CHEATSHEET.md)**.

## Fitur (pasca-v1)

- **OCR struk/nota → transaksi (v2)**: kirim foto struk ke bot → OCR (OCR.space free tier) → parse (merchant/nominal/tanggal) → konfirmasi → posting `KK`. Confidence < 50% → minta input manual. Semua tetap di Vercel serverless (tanpa Railway/FastAPI), same-origin auth utuh. Detail: **[docs/API.md](docs/API.md)**.
- **API layer integrasi (v2)**: `POST /api/transactions` (buat transaksi) & `POST /api/receipts/parse` (OCR), auth via cookie **atau** header `X-API-Key` — base untuk menyambung project lain.
- **Bot**: `/nihil` (catat hari tanpa transaksi + ping Supabase), menu command ber-ikon emoji.
- **Dashboard**: pemilih bulan (◀ ▶), grafik akumulasi pengeluaran harian, chart beban per kategori, logo + footer.
- **Settings**: edit Default Akun (dropdown dari `bot_settings`), Logout.
- **Export `.xlsx`**: Jurnal, Buku Besar, Laporan (Laba Rugi & Trial Balance).
- **Buku Besar**: 7 dropdown akun per kelas (Aset…Lain-lain).
- **Keamanan**: RLS semua tabel, webhook secret token (opsional), audit trail config tables + soft-delete alias.
- **Otomasi**: GitHub Actions keepalive (3 hari) + backup harian (`pg_dump` via session pooler, PG17).

## Blindspot fixes yang sudah diterapkan

| # | Fix | Lokasi |
|---|-----|--------|
| B1 | PgBouncer port 6543 | `shared/db.py`, `.env.example` |
| B2 | Register webhook | `scripts/setup_webhook.py` |
| B3 | SPA catch-all route | `vercel.json` |
| B4 | `bot_state` upsert atomik | `shared/state.py` + RPC |
| B5 | `/api/auth/me` | `api/auth/me.py` |
| B6 | Guard double `/setup` | `webhook.py:cmd_setup` |
| B7 | Bot pakai raw `httpx` (bukan PTB) | `shared/telegram.py` |
| B8 | Keepalive cron | `.github/workflows/keepalive.yml` |
| B9 | Backup pg_dump harian | workflow + `scripts/backup_db.py` |
| B10 | ngrok dev tunnel | `scripts/ngrok.ps1` |
| B11 | Runtime python3.12 eksplisit | `vercel.json` |
| B12 | Cache fetch TTL 30s | `src/hooks/useTransactions.js` |
| B13 | Pagination `limit`/`offset` | `shared/http.py`, API |
| B14 | Reverse di tanggal kini | RPC `reverse_document` |
| B15 | Penyusutan skip personal | COA (akun ada, saldo 0) |

Plus: atomic doc-number (`next_doc_seq`), double-entry & period-lock guard di RPC `post_document`, no-delete + audit trigger di `01_schema.sql`.
