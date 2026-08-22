import os
import sys
from pathlib import Path

from dotenv import load_dotenv
load_dotenv()

import psycopg

def run_migrations(dsn: str) -> None:
    migrations_dir = Path(__file__).parent
    files = sorted(migrations_dir.glob("*.sql"))
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
            # Track what has run so re-running the suite is safe. Without this
            # the first CREATE TABLE aborts on an already-migrated database.
            cur.execute(
                "CREATE TABLE IF NOT EXISTS public.schema_migrations ("
                "  filename TEXT PRIMARY KEY,"
                "  applied_at TIMESTAMP NOT NULL DEFAULT now())"
            )
            cur.execute("SELECT filename FROM public.schema_migrations")
            applied = {row[0] for row in cur.fetchall()}

            for f in files:
                if f.name in applied:
                    print(f"Skipping {f.name} (already applied)")
                    continue
                print(f"Applying {f.name}...")
                cur.execute(f.read_text())
                cur.execute(
                    "INSERT INTO public.schema_migrations (filename) VALUES (%s)",
                    (f.name,),
                )
    print(f"Applied {len(files)} migration(s).")

if __name__ == "__main__":
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        print("DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)
    run_migrations(dsn)
