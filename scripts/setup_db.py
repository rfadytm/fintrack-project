"""Jalankan semua SQL migrations (db/*.sql) secara berurutan.

Butuh psql + SUPABASE_DB_URL (port 6543 PgBouncer, lihat .env.example).
Alternatif: copy-paste manual tiap file ke Supabase SQL Editor (urutan 01->07).

Usage:
    python scripts/setup_db.py
"""
import glob
import os
import subprocess
import sys

from dotenv import load_dotenv

load_dotenv()


def main():
    db_url = os.environ.get("SUPABASE_DB_URL")
    if not db_url:
        print("SUPABASE_DB_URL belum di-set. Jalankan SQL manual via Supabase SQL Editor.")
        sys.exit(1)

    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(here, "db", "*.sql")))
    for f in files:
        print(f"→ {os.path.basename(f)}")
        res = subprocess.run(["psql", db_url, "-v", "ON_ERROR_STOP=1", "-f", f])
        if res.returncode != 0:
            print(f"  ⚠️ gagal di {f}")
            sys.exit(1)
    print("✅ Semua migration selesai.")


if __name__ == "__main__":
    main()
