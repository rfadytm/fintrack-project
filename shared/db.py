"""Supabase client singleton.

B1 — Connection pooling:
- supabase-py memakai REST/PostgREST lewat HTTPS (SUPABASE_URL), bukan koneksi
  Postgres langsung, jadi tidak ada masalah pool exhaustion port 5432 di serverless.
- Untuk koneksi Postgres LANGSUNG (mis. pg_dump backup / psql), WAJIB pakai
  port 6543 (PgBouncer) + ?pgbouncer=true — lihat SUPABASE_DB_URL di .env.example.
"""
import os
from functools import lru_cache

from supabase import Client, create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]


@lru_cache(maxsize=1)
def get_client() -> Client:
    """Reuse 1 client per warm Vercel function instance."""
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
