# DEPLOY.md — Step by Step

## 0. Prasyarat
- Akun: Supabase (free), Vercel (Hobby), Telegram bot via @BotFather, GitHub.
- Lokal: Node 18+, Python 3.12, (opsional) `psql`/`pg_dump` untuk migration & backup.

## 1. Telegram bot
1. Chat @BotFather → `/newbot` → simpan **token**.
2. Dapatkan **Telegram user ID** kamu (chat @userinfobot).

## 2. Supabase
1. app.supabase.com → **New Project** (free, no CC).
2. SQL Editor → jalankan `db/01_schema.sql` … `db/07_functions.sql` **berurutan**.
   (atau lokal tanpa psql: isi `SUPABASE_DB_URL`, `pip install psycopg2-binary python-dotenv`, lalu `python scripts/migrate.py`)
3. Settings → API: salin **Project URL** + **service_role key**.
4. Settings → Database → Connection string (Transaction/PgBouncer, **port 6543**) untuk `SUPABASE_DB_URL` (tambahkan `?pgbouncer=true`).

## 3. Env vars
`cp .env.example .env`, isi: `TELEGRAM_BOT_TOKEN`, `OWNER_TELEGRAM_ID`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `AUTH_SECRET` (`python -c "import secrets;print(secrets.token_hex(32))"`), `SUPABASE_DB_URL`.

## 4. GitHub
Karena GitHub sudah konek ke VS Code → pakai **Source Control → Publish to GitHub** (pilih **private**), atau:
```
git init && git add . && git commit -m "init: FinTrack v1"
git branch -M main
git remote add origin https://github.com/<user>/fintrack.git
git push -u origin main
```

## 5. Vercel
1. vercel.com/new → Import repo.
2. Settings → Environment Variables → tambahkan semua dari `.env` **kecuali** yang khusus lokal. Tambahkan juga `APP_URL=https://<app>.vercel.app` (untuk link `/getlink`).
3. Deploy.

## 6. Webhook (B2 — WAJIB tiap kali domain berubah)
```
python scripts/setup_webhook.py https://<app>.vercel.app
```

## 7. GitHub Actions (keepalive + backup)
Repo → Settings → Secrets and variables → Actions → tambahkan:
`SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_DB_URL`.
Workflow `keepalive.yml` aktif otomatis (B8 ping tiap 3 hari, B9 backup harian).

## 8. First run
Telegram: `/start` → `/setup` (input saldo awal BNI/SeaBank/Tunai) → coba `/menu` → catat 1 pengeluaran.
Dashboard: `/getlink` → klik link → cek data muncul.

## Troubleshooting
- **Bot diam**: cek `getWebhookInfo` (jalankan setup_webhook lagi), cek `OWNER_TELEGRAM_ID` benar.
- **Refresh halaman 404**: pastikan catch-all route ada di `vercel.json` (sudah).
- **DB pool error**: pastikan `SUPABASE_DB_URL` port **6543** + `?pgbouncer=true`.
- **Deploy Python besar**: bot pakai `httpx` saja (bukan python-telegram-bot) → function kecil.
