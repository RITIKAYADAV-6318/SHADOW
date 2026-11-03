"""Central settings for the Personal DSA Mentor.

Everything tunable lives here, and every secret comes from .env (never from source).
Import `settings` anywhere; call `validate()` to get a list of setup problems.
"""

import os
import re
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")


def _env(name: str, default: str = "") -> str:
    """Read an env var, strip stray whitespace, and fall back to the default if blank."""
    return os.getenv(name, "").strip() or default


@dataclass(frozen=True)
class Settings:
    # --- server -------------------------------------------------------------
    env: str = _env("MENTOR_ENV", "dev")
    host: str = "127.0.0.1"  # never change this to 0.0.0.0
    port: int = int(_env("MENTOR_PORT", "8765"))
    token: str = _env("MENTOR_TOKEN")
    extension_id: str = _env("MENTOR_EXTENSION_ID")  # the only origin CORS will allow

    # --- storage ------------------------------------------------------------
    db_path: Path = ROOT / _env("MENTOR_DB", "data/mentor.db")

    # --- LLM (Gemini free tier) ----------------------------------------------
    gemini_api_key: str = _env("GEMINI_API_KEY")
    gemini_model: str = _env("GEMINI_MODEL")
    llm_daily_call_cap: int = int(_env("LLM_DAILY_CALL_CAP", "100"))
    enrich_daily_cap: int = int(_env("ENRICH_DAILY_CAP", "30"))

    # --- identity -----------------------------------------------------------
    user_id: int = 1  # single user for now, but keep user_id everywhere

    # --- tunable rules (see build plan section 1) -----------------------------
    attempt_gap_hours: int = 6  # reopening after this long = new attempt
    idle_cutoff_sec: int = 180  # idle longer than this isn't active time
    junk_min_active_sec: int = 120  # shorter attempts (with no submission) are ignored
    day_cutoff: str = "04:00"  # local time a "day" rolls over
    ema_alpha: float = 0.3  # mastery update rate


settings = Settings()


def validate() -> list[str]:
    """Return human-readable setup problems (an empty list means all good)."""
    problems: list[str] = []
    if len(settings.token) < 24 or settings.token == "change-me":
        problems.append("MENTOR_TOKEN is missing or too short")
    if not settings.gemini_api_key or settings.gemini_api_key.startswith("your-"):
        problems.append("GEMINI_API_KEY is not set (fine until Day 8)")
    if not settings.gemini_model or settings.gemini_model.startswith("put-"):
        problems.append("GEMINI_MODEL is not set (fine until Day 8)")
    if not settings.extension_id or settings.extension_id.startswith("paste-"):
        problems.append("MENTOR_EXTENSION_ID is not set (needed on Day 2 for CORS)")
    elif not re.fullmatch(r"[a-p]{32}", settings.extension_id):
        problems.append("MENTOR_EXTENSION_ID doesn't look like a Chrome extension ID "
                        "(32 letters a-p); paste only the ID, not the URL")
    return problems
