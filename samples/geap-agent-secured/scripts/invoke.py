"""Send a question to the deployed secured agent and print the answer.

Usage: python scripts/invoke.py "question"  (needs GCP_PROJECT_ID, REASONING_ENGINE_ID in the env).
"""

import json
import os
import sys
import time
from typing import Any

import google.auth
import google.auth.transport.requests
import requests


def stream_parts(question: str, user_id: str = "sample-user") -> list[dict[str, Any]]:
    """Stream a question to the deployed engine and return every content part of the answer events."""
    project = os.environ["GCP_PROJECT_ID"]
    region = os.environ.get("GCP_REGION", "europe-west1")
    engine = os.environ["REASONING_ENGINE_ID"]

    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    credentials.refresh(google.auth.transport.requests.Request())
    url = (
        f"https://{region}-aiplatform.googleapis.com/v1/projects/{project}"
        f"/locations/{region}/reasoningEngines/{engine}:streamQuery?alt=sse"
    )
    payload = {"class_method": "async_stream_query", "input": {"user_id": user_id, "message": question}}
    parts: list[dict[str, Any]] = []
    with requests.post(
        url,
        headers={"Authorization": f"Bearer {credentials.token}"},
        json=payload,
        stream=True,
        timeout=180,
    ) as response:
        response.raise_for_status()
        for raw in response.iter_lines():
            line = raw.decode() if isinstance(raw, bytes) else raw
            if not line:
                continue
            try:
                event = json.loads(line.removeprefix("data: "))
            except json.JSONDecodeError:
                continue
            if not isinstance(event, dict):
                continue
            detail = _event_error(event)
            if detail:
                raise AgentError(detail)
            parts.extend((event.get("content") or {}).get("parts", []))
    return parts


class AgentError(RuntimeError):
    """The agent reported an error, or returned no answer."""


def _event_error(event: dict[str, Any]) -> str | None:
    """Return the error detail carried by a streamed event, if any (ADK or Vertex API error shapes)."""
    error = event.get("error")
    if isinstance(error, dict):
        return str(error.get("message") or error)
    if error:
        return str(error)
    if event.get("error_code") or event.get("error_message"):
        return f"{event.get('error_code', '')} {event.get('error_message', '')}".strip()
    if isinstance(event.get("code"), int) and event["code"] >= 400:
        return str(event.get("message") or event["code"])
    return None


def query(question: str, user_id: str = "sample-user") -> str:
    """Stream a question to the deployed engine and return the concatenated text of the answer."""
    return "\n".join(part["text"] for part in stream_parts(question, user_id) if "text" in part)


def main() -> int:
    if len(sys.argv) < 2:
        print('usage: invoke.py "question"', file=sys.stderr)
        return 2
    started = time.monotonic()
    try:
        answer = query(sys.argv[1])
        if not answer.strip():
            raise AgentError("the agent returned an empty answer")
    except (AgentError, requests.RequestException) as exc:
        print(
            f"ERROR: the request failed and the agent cannot answer it ({exc}). "
            "Check the agent logs in Cloud Logging for the exception.",
            file=sys.stderr,
        )
        print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
        return 1
    print(answer)
    print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
