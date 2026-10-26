"""Send a question to the deployed agent through the ingress gateway and print the answer.

Usage: python scripts/invoke.py "question"  (needs GCP_PROJECT_ID, REASONING_ENGINE_ID in the env).

Only `async_stream_query` through `:streamQuery` is exposed: it is the method Model Armor screens.
"""

import json
import os
import sys
import time
from typing import Any

import google.auth
import google.auth.transport.requests
import requests


class AgentError(RuntimeError):
    """The request was refused (HTTP error, e.g. by the gateway), the agent reported an error, or no answer."""

    def __init__(self, detail: str, status_code: int | None = None) -> None:
        super().__init__(detail if status_code is None else f"HTTP {status_code}: {detail}")
        self.status_code = status_code


def engine_url(method: str) -> str:
    """URL of a method (`streamQuery`, `query`, `sessions`) of the deployed engine."""
    project = os.environ["GCP_PROJECT_ID"]
    region = os.environ.get("GCP_REGION", "europe-west1")
    engine = os.environ["REASONING_ENGINE_ID"]
    separator = "/" if method == "sessions" else ":"
    return (
        f"https://{region}-aiplatform.googleapis.com/v1/projects/{project}"
        f"/locations/{region}/reasoningEngines/{engine}{separator}{method}"
    )


def auth_headers() -> dict[str, str]:
    """Bearer token of the caller (Application Default Credentials)."""
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    credentials.refresh(google.auth.transport.requests.Request())
    return {"Authorization": f"Bearer {credentials.token}"}


def stream_events(question: str, user_id: str = "sample-user") -> list[Any]:
    """Stream a question to the deployed engine and return every decoded event of the answer."""
    return stream_method("async_stream_query", {"user_id": user_id, "message": question})


def stream_method(class_method: str, method_input: dict[str, Any]) -> list[Any]:
    """Call a streaming class method of the deployed engine through `:streamQuery` and return its decoded events."""
    payload = {"class_method": class_method, "input": method_input}
    events: list[Any] = []
    with requests.post(
        f"{engine_url('streamQuery')}?alt=sse",
        headers=auth_headers(),
        json=payload,
        stream=True,
        timeout=180,
    ) as response:
        if response.status_code >= 400:
            raise AgentError(response.text.strip() or str(response.reason), status_code=response.status_code)
        for raw in response.iter_lines():
            line = raw.decode() if isinstance(raw, bytes) else raw
            if not line:
                continue
            try:
                events.append(json.loads(line.removeprefix("data: ")))
            except json.JSONDecodeError:
                events.append(line)  # kept as text: a gateway may stream a non-JSON error
    return events


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
    """Return the concatenated text of the answer; raise AgentError on any error event."""
    texts: list[str] = []
    for event in stream_events(question, user_id):
        if not isinstance(event, dict):
            raise AgentError(f"unexpected event: {event}")
        detail = _event_error(event)
        if detail:
            raise AgentError(detail)
        texts.extend(part["text"] for part in (event.get("content") or {}).get("parts", []) if "text" in part)
    return "\n".join(texts)


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
            "A prompt rejected by Model Armor ends here too (HTTP 403 'Model Armor: ...'); otherwise check the "
            "agent logs.",
            file=sys.stderr,
        )
        print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
        return 1
    print(answer)
    print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
