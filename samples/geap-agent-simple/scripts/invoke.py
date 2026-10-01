"""Send a question to the deployed agent and print the answer, duration and token usage.

Usage: python scripts/invoke.py "question"  (needs GCP_PROJECT_ID, REASONING_ENGINE_ID in the env).
"""

import json
import os
import sys
import time

import google.auth
import google.auth.transport.requests
import requests


def main() -> int:
    if len(sys.argv) < 2:
        print('usage: invoke.py "question"', file=sys.stderr)
        return 2
    project = os.environ["GCP_PROJECT_ID"]
    region = os.environ.get("GCP_REGION", "europe-west1")
    engine = os.environ["REASONING_ENGINE_ID"]

    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    credentials.refresh(google.auth.transport.requests.Request())
    url = (
        f"https://{region}-aiplatform.googleapis.com/v1/projects/{project}"
        f"/locations/{region}/reasoningEngines/{engine}:streamQuery?alt=sse"
    )
    payload = {
        "class_method": "async_stream_query",
        "input": {"user_id": "sample-user", "message": sys.argv[1]},
    }
    started = time.monotonic()
    with requests.post(
        url,
        headers={"Authorization": f"Bearer {credentials.token}"},
        json=payload,
        stream=True,
        timeout=120,
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
                    print(part["text"])
    print(f"-- duration: {time.monotonic() - started:.1f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
