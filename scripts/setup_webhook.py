"""B2: Register Telegram webhook ke Vercel URL. Jalankan setelah tiap deploy.

Usage:
    python scripts/setup_webhook.py https://your-app.vercel.app
    python scripts/setup_webhook.py --delete   # hapus webhook (balik ke polling/dev)
"""
import os
import sys

import httpx
from dotenv import load_dotenv

load_dotenv()
TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
API = f"https://api.telegram.org/bot{TOKEN}"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == "--delete":
        r = httpx.post(f"{API}/deleteWebhook")
        print(r.json())
        return

    base = sys.argv[1].rstrip("/")
    url = f"{base}/api/telegram/webhook"
    r = httpx.post(
        f"{API}/setWebhook",
        json={"url": url, "allowed_updates": ["message", "callback_query"]},
    )
    print("setWebhook:", r.json())
    print("info:", httpx.get(f"{API}/getWebhookInfo").json())


if __name__ == "__main__":
    main()
