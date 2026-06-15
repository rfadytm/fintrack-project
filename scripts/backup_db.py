"""B9: backup database via pg_dump. Dipakai manual & oleh GitHub Actions.

Butuh pg_dump + SUPABASE_DB_URL (port 6543 PgBouncer).
Usage:
    python scripts/backup_db.py            # -> backups/fintrack_YYYY-MM-DD.sql
    python scripts/backup_db.py out.sql
"""
import os
import subprocess
import sys
from datetime import datetime, timezone

from dotenv import load_dotenv

load_dotenv()


def main():
    db_url = os.environ.get("SUPABASE_DB_URL")
    if not db_url:
        print("SUPABASE_DB_URL belum di-set.")
        sys.exit(1)

    os.makedirs("backups", exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = sys.argv[1] if len(sys.argv) > 1 else f"backups/fintrack_{stamp}.sql"

    res = subprocess.run(["pg_dump", db_url, "--no-owner", "--no-privileges", "-f", out])
    if res.returncode != 0:
        sys.exit(1)
    print(f"✅ Backup -> {out}")


if __name__ == "__main__":
    main()
