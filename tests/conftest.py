"""Env vars dummy supaya shared/auth.py, shared/telegram.py, dan api/telegram/webhook.py
bisa di-import di test tanpa .env asli.

SENGAJA TIDAK termasuk SUPABASE_URL/SUPABASE_SERVICE_KEY di sini — test_db.py pakai
`skipif(not os.environ.get("SUPABASE_URL"), ...)` untuk skip smoke-test koneksi asli
kalau credential belum di-set; men-set dummy value di sini secara global akan bikin
skip-guard itu salah kira ada credential asli lalu mencoba connect sungguhan dan gagal.
Modul yang butuh shared.db bisa di-import (test_activity.py, test_webhook_flows.py)
men-set env var itu sendiri secara lokal sebelum import, di-scope ke file itu saja.
"""
import os

os.environ.setdefault("AUTH_SECRET", "test-auth-secret")
os.environ.setdefault("TELEGRAM_BOT_TOKEN", "test-telegram-token")
os.environ.setdefault("OWNER_TELEGRAM_ID", "111")
