"""Quick self-test of the setup. Reusable any time.

Run from the repo root:  python -m scripts.check_setup
"""

from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from backend.config import settings, validate
from backend.db.database import db

EXPECTED_TABLES = {
    "users", "profile", "baseline_metrics", "schedule_blocks", "events", "problems",
    "attempts", "tasks", "mastery", "reviews", "state_snapshot", "study_sessions",
    "memories", "interventions", "notifications", "private_notes", "llm_calls",
}


def main() -> None:
    print("host:", settings.host, "port:", settings.port)
    for problem in validate():
        print("note:", problem)

    with db() as conn:
        mode = conn.execute("PRAGMA journal_mode;").fetchone()[0]
        tables = {
            r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
        }
        row = conn.execute("SELECT timezone FROM users WHERE id = 1").fetchone()
        version = conn.execute("PRAGMA user_version;").fetchone()[0]

    print("journal_mode:", mode)
    print("schema version:", version)
    missing = EXPECTED_TABLES - tables
    print("missing tables:", sorted(missing) or "none")

    tzname = (row["timezone"] if row else None) or "UTC"
    try:
        ZoneInfo(tzname)
        print(f"timezone data: ok ({tzname})")
    except ZoneInfoNotFoundError:
        print("timezone data: MISSING for", tzname, "-> pip install tzdata")


if __name__ == "__main__":
    main()
