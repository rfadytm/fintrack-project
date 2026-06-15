# CHEATSHEET

## Bot commands
| Command | Fungsi |
|---------|--------|
| `/start` | Welcome + cek setup |
| `/menu` | Menu utama inline |
| `/saldo` | Saldo semua akun + net worth |
| `/hari` / `/bulan [YYYY-MM]` | Ringkasan harian/bulanan |
| `/recent [n]` | n transaksi terakhir (detail/reverse) |
| `/getlink` | Link login dashboard (60 mnt, sekali pakai) |
| `/lock YYYY-MM` | Kunci periode |
| `/setup` | Wizard saldo awal (sekali) |
| `/reverse DOC` | Reverse transaksi (RV di tgl kini) |
| `/reset` | Batalkan input berjalan |

## Dev lokal
```bash
npm install && npm run dev          # frontend :5173 (proxy /api -> :3000)
vercel dev                          # backend serverless :3000
python scripts/ngrok.ps1            # tunnel untuk webhook lokal
python scripts/setup_webhook.py https://<ngrok>.ngrok-free.app
```

## DB / migration
```bash
python scripts/setup_db.py          # jalankan db/*.sql (butuh SUPABASE_DB_URL)
python scripts/backup_db.py         # backup manual -> backups/
```

## Doc number
`TYPE-YYYY-MM-NNN` — OB(saldo awal) KK(keluar) KM(masuk) TR(transfer) JU(jurnal) RV(reverse). Reset per bulan, atomik via `next_doc_seq`.

## Akun kas
`1110` Tunai · `1120` BNI (kas besar) · `1130` SeaBank (kas kecil imprest Rp500rb) · `1140` Tabungan.

## Amount parsing
`25000` `25.000` `25,000` `25k` `25rb` → 25.000 · `25jt`→25jt · `2,5jt`→2.500.000.

## API endpoints
`GET /api/auth/me` · `POST /api/auth/verify` · `GET /api/accounts` · `GET /api/transactions?limit=&offset=&type=` · `GET /api/reports/{balance,monthly,ledger,trial-balance,income-statement}`
