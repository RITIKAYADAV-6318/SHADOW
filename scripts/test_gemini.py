"""Check that the Gemini key and model work.

Run from the repo root:  python -m scripts.test_gemini
"""

from google import genai
from google.genai import types

from backend.config import settings


def main() -> None:
    if not settings.gemini_api_key or not settings.gemini_model:
        print("Set GEMINI_API_KEY and GEMINI_MODEL in .env first.")
        return

    client = genai.Client(
        api_key=settings.gemini_api_key,
        http_options=types.HttpOptions(timeout=30_000),  # milliseconds
    )
    try:
        resp = client.models.generate_content(
            model=settings.gemini_model,
            contents="Reply with the single word: ready",
        )
        print(f"ok: {settings.gemini_model} -> {resp.text.strip()}")
    except Exception as exc:  # network, bad key or bad model name
        print("FAILED:", type(exc).__name__, str(exc)[:300])
        print("\nModels your key can call (use one as GEMINI_MODEL):")
        try:
            for m in client.models.list():
                if "generateContent" in (getattr(m, "supported_actions", None) or []):
                    print(" ", m.name.removeprefix("models/"))
        except Exception as exc2:
            print("could not list models:", type(exc2).__name__)


if __name__ == "__main__":
    main()