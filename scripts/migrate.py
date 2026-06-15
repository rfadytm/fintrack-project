"""Jalankan db/*.sql berurutan via psycopg2 (alternatif setup_db.py tanpa psql CLI).

Usage: python scripts/migrate.py
"""
import glob
import os
import sys

import psycopg2
from dotenv import load_dotenv

load_dotenv()


def main():
    dsn = os.environ.get("SUPABASE_DB_URL")
    if not dsn:
        print("SUPABASE_DB_URL belum di-set di .env")
        sys.exit(1)

    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(here, "db", "*.sql")))

    conn = psycopg2.connect(dsn)
    conn.autocommit = True
    try:
        for f in files:
            name = os.path.basename(f)
            with open(f, "r", encoding="utf-8") as fh:
                sql = fh.read()
            print(f"→ {name} ...", end=" ")
            with conn.cursor() as cur:
                cur.execute(sql)  # tanpa params: literal % aman
            print("OK")
    finally:
        conn.close()
    print("✅ Semua migration selesai.")


if __name__ == "__main__":
    main()
