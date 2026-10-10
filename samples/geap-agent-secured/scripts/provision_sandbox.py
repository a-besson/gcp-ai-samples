"""Provision the code-execution sandbox of the deployed secured agent (idempotent).

Usage: python scripts/provision_sandbox.py  (needs GCP_PROJECT_ID, REASONING_ENGINE_ID in the env).

Reuses a running sandbox valid for more than RENEW_BEFORE; otherwise creates one, checks that it runs code,
then deletes the older ones. The creation operation is NOT awaited: on this gateway-bound engine it ends in
UNAVAILABLE after ~9 min although the sandbox runs code within seconds (docs/VERIFICATION.md at the repository root).
"""

import os
import sys
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))

from sandbox import SANDBOX_DISPLAY_NAME, client_for, usable_sandboxes  # noqa: E402

# The agent finds the sandbox by display name; `task apply` and `task e2e` renew it before it expires.
TTL = timedelta(days=7)
RENEW_BEFORE = timedelta(days=1)
READY_TIMEOUT_SECONDS = 120
POLL_SECONDS = 5


def _wait_until_it_runs_code(client: Any, engine: str, known: set[str]) -> str:
    """Return the new sandbox once it answers a trivial execution, or raise TimeoutError."""
    deadline = time.monotonic() + READY_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        new = [s for s in usable_sandboxes(client, engine) if s.name not in known]
        if new:
            try:
                response = client.agent_engines.sandboxes.execute_code(
                    name=new[0].name, input_data={"code": "print(6 * 7)"}
                )
                if any(b"42" in (output.data or b"") for output in response.outputs):
                    return new[0].name
            except Exception as exc:  # not ready yet: retry until the deadline
                print(f"sandbox not ready yet: {type(exc).__name__}", file=sys.stderr)
        time.sleep(POLL_SECONDS)
    raise TimeoutError(f"no usable sandbox after {READY_TIMEOUT_SECONDS}s")


def provision(client: Any, engine: str) -> str:
    """Return the resource name of a usable sandbox, creating it when needed."""
    current = usable_sandboxes(client, engine)
    if current and current[0].expire_time - datetime.now(UTC) > RENEW_BEFORE:
        return current[0].name

    client.agent_engines.sandboxes.create(
        name=engine,
        spec={"code_execution_environment": {}},
        config={
            "display_name": SANDBOX_DISPLAY_NAME,
            "ttl": f"{int(TTL.total_seconds())}s",
            "wait_for_completion": False,  # see the module docstring
        },
    )
    name = _wait_until_it_runs_code(client, engine, {s.name for s in current})
    for old in current:
        client.agent_engines.sandboxes.delete(name=old.name)
    return name


def main() -> int:
    project = os.environ["GCP_PROJECT_ID"]
    region = os.environ.get("GCP_REGION", "europe-west1")
    engine = f"projects/{project}/locations/{region}/reasoningEngines/{os.environ['REASONING_ENGINE_ID']}"
    print(provision(client_for(engine), engine))
    return 0


if __name__ == "__main__":
    sys.exit(main())
