"""One timestamp format for every writer (backend, notifier, scripts).

Canonical stored format: UTC, fixed width, milliseconds, trailing Z, e.g.
2026-10-25T13:18:47.552Z (identical to JavaScript's Date.toISOString()).

Fixed width means plain text comparison and ORDER BY ts sort chronologically.
Mixed formats (for example "...+00:00" with microseconds) silently break that,
so always go through these helpers.
"""

from datetime import datetime, timezone


def to_iso(dt: datetime) -> str:
    """Format a datetime in the canonical form. A naive datetime is treated as local time."""
    dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def utc_now_iso() -> str:
    """Current time in the canonical form."""
    return to_iso(datetime.now(timezone.utc))


def parse_iso(s: str) -> datetime:
    """Parse '...Z' or '...+00:00' (with or without fractions) into an aware datetime."""
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def normalize_ts(s: str) -> str:
    """Accept any ISO-8601 variant and return the canonical form."""
    return to_iso(parse_iso(s))
