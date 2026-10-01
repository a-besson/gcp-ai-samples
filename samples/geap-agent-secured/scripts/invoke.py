"""Send a question to the deployed secured agent and print the answer.

Usage: python scripts/invoke.py "question"  (needs GCP_PROJECT_ID, REASONING_ENGINE_ID in the env).
"""

import json
import os
import sys
import time

import google.auth
import google.auth.transport.requests
import requests


def query(question: str, user_id: str = "sample-user") -> str:
    """Stream a question to the deployed engine and return the concatenated text of the answer."""
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
    answer: list[str] = []
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
            for part in event.get("content", {}).get("parts", []):
                if "text" in part:
                    answer.append(part["text"])
    return "\n".join(answer)


def main() -> int:
    if len(sys.argv) < 2:
        print('usage: invoke.py "question"', file=sys.stderr)
        return 2
    started = time.monotonic()
    print(query(sys.argv[1]))
    print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
