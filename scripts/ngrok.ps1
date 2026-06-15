# B10: Local dev tunnel. Telegram tidak bisa kirim ke localhost.
# 1. Jalankan `vercel dev` (atau backend lokal) di port 3000.
# 2. Jalankan script ini untuk buka tunnel.
# 3. Daftarkan URL ngrok sebagai webhook:
#       python scripts/setup_webhook.py https://<subdomain>.ngrok-free.app
# Prasyarat: ngrok terinstal + sudah `ngrok config add-authtoken <token>`.

param([int]$Port = 3000)
Write-Host "Membuka ngrok tunnel ke http://localhost:$Port ..." -ForegroundColor Cyan
ngrok http $Port
