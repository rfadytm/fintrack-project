"""Daftarkan command menu bot ke Telegram (muncul di menu "/" & tombol menu biru).

Usage: python scripts/set_commands.py
"""
import os

import httpx
from dotenv import load_dotenv

load_dotenv()
TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
API = f"https://api.telegram.org/bot{TOKEN}"

COMMANDS = [
    ("start", "Mulai & menu utama"),
    ("menu", "Tampilkan menu utama"),
    ("saldo", "Saldo semua akun"),
    ("nihil", "Catat: tidak ada transaksi hari ini"),
    ("hari", "Ringkasan hari ini"),
    ("bulan", "Ringkasan bulan (opsional YYYY-MM)"),
    ("recent", "Transaksi terakhir (opsional n)"),
    ("getlink", "Link login dashboard"),
    ("setup", "Set saldo awal (sekali)"),
    ("lock", "Kunci periode (YYYY-MM)"),
    ("reverse", "Batalkan transaksi (DOC)"),
    ("reset", "Batalkan input berjalan"),
    ("help", "Daftar perintah"),
]


def main():
    r = httpx.post(
        f"{API}/setMyCommands",
        json={"commands": [{"command": c, "description": d} for c, d in COMMANDS]},
    )
    print("setMyCommands:", r.json())
    # Tampilkan tombol menu sebagai daftar command
    r2 = httpx.post(f"{API}/setChatMenuButton", json={"menu_button": {"type": "commands"}})
    print("setChatMenuButton:", r2.json())


if __name__ == "__main__":
    main()
