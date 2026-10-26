"""Check that the model answers in EU locations, with the caller's credentials (a few tokens each).

Usage: python scripts/check_model.py [location ...]  (default: eu; needs GCP_PROJECT_ID, MODEL).

Run it before `task apply`: Claude is a partner model that must be enabled in Model Garden, and its quota in a
location may be zero. A Gemini model (temporary fallback) is checked through google-genai on Vertex AI.
"""

import os
import sys

from anthropic import APIStatusError
from anthropic.lib.vertex import AnthropicVertex
from google import genai
from google.genai import errors

# Same allowed list as app/config.py
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
from config import EU_MODEL_LOCATIONS  # noqa: E402

HINTS = {
    403: "permission denied, or the model is not enabled for the project (Model Garden > Claude > Enable)",
    404: "model not served in this location, or wrong model ID",
    429: "no quota in this location (request one, or try another location)",
}
# Room for the thinking tokens of Gemini models, which count as output tokens
MAX_TOKENS = {"claude-": 5, "gemini-": 256}


def _ko(location: str, status: int, message: str) -> bool:
    hint = f" ({HINTS[status]})" if status in HINTS else ""
    print(f"{location:<18} KO  HTTP {status}{hint}: {message[:300]}")
    return False


def check_claude(project: str, model: str, location: str) -> bool:
    client = AnthropicVertex(project_id=project, region=location, max_retries=0, timeout=60.0)
    try:
        message = client.messages.create(
            model=model,
            max_tokens=MAX_TOKENS["claude-"],
            messages=[{"role": "user", "content": "Reply with the single word OK."}],
        )
    except APIStatusError as exc:
        return _ko(location, exc.status_code, exc.message)
    text = "".join(block.text for block in message.content if block.type == "text").strip()
    print(f"{location:<18} OK  {text!r} ({message.usage.input_tokens} in / {message.usage.output_tokens} out tokens)")
    return True


def check_gemini(project: str, model: str, location: str) -> bool:
    client = genai.Client(vertexai=True, project=project, location=location)
    try:
        response = client.models.generate_content(
            model=model,
            contents="Reply with the single word OK.",
            config={"max_output_tokens": MAX_TOKENS["gemini-"]},
        )
    except errors.APIError as exc:
        return _ko(location, exc.code, str(exc.message))
    usage = response.usage_metadata
    tokens = f"{usage.prompt_token_count} in / {usage.total_token_count} total tokens" if usage else "no usage"
    print(f"{location:<18} OK  {(response.text or '').strip()!r} ({tokens})")
    return True


def main() -> int:
    project, model = os.environ["GCP_PROJECT_ID"], os.environ.get("MODEL", "claude-haiku-5-5")
    locations = sys.argv[1:] or ["eu"]
    outside = [location for location in locations if location not in EU_MODEL_LOCATIONS]
    if outside:
        print(f"refused, not an EU location: {', '.join(outside)}", file=sys.stderr)
        return 2
    check = check_gemini if model.startswith("gemini-") else check_claude
    print(f"model {model}")
    results = [check(project, model, location) for location in locations]
    return 0 if any(results) else 1


if __name__ == "__main__":
    sys.exit(main())
