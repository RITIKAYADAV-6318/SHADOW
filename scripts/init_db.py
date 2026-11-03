"""Create the database tables and the single user.

Run from the repo root:  python -m scripts.init_db
"""

from backend.db.database import db, init_db
from backend.timeutil import utc_now_iso

TIMEZONE = "Asia/Kolkata"  # IANA timezone name


def main() -> None:
    init_db()
    with db() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO users (id, name, timezone, created_at) "
            "VALUES (1, 'me', ?, ?)",
            (TIMEZONE, utc_now_iso()),
        )
        conn.execute("INSERT OR IGNORE INTO profile (user_id) VALUES (1)")
    print("database initialised")


if __name__ == "__main__":
    main()
