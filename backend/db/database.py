"""SQLite access. Always use `with db() as conn:`.

The backend, the notifier and scripts all touch one database file, so every
connection uses WAL mode plus a busy timeout to avoid "database is locked".
"""

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from backend.config import settings

SCHEMA_VERSION = 1  # bump when the schema changes, and add a migration step


def connect() -> sqlite3.Connection:
    """Raw connection. Prefer db() below, which commits and always closes."""
    settings.db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA busy_timeout=5000;")
    conn.execute("PRAGMA foreign_keys=ON;")
    return conn


@contextmanager
def db() -> Iterator[sqlite3.Connection]:
    """Commit on success, roll back on error, and ALWAYS close.

    sqlite3's own `with conn:` commits but does not close, and on Windows a
    lingering handle can block copying or moving the database file (which the
    daily backups do).
    """
    conn = connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    """Create all tables (safe to re-run). Stamps the schema version on a fresh database."""
    schema = (Path(__file__).with_name("schema.sql")).read_text(encoding="utf-8")
    with db() as conn:
        conn.executescript(schema)
        if conn.execute("PRAGMA user_version;").fetchone()[0] == 0:
            conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION};")