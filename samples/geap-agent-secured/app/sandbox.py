"""Pre-provisioned code-execution sandbox, shared by the agent (lookup) and scripts/provision_sandbox.py.

On this gateway-bound engine, CreateSandboxEnvironment creates a working sandbox within a second, but its
long-running operation ends in UNAVAILABLE after ~9 min (docs/VERIFICATION.md at the repository root). The ADK
executor waits for that operation, so the sandbox is created ahead of time (`task sandbox`) and found by display name.
"""

import re
from datetime import UTC, datetime
from typing import Any

import vertexai

SANDBOX_DISPLAY_NAME = "geap-agent-secured-sandbox"


def client_for(engine_resource_name: str) -> Any:
    """Vertex AI client in the project and region of the engine (sandboxes live under it)."""
    match = re.fullmatch(r"projects/([^/]+)/locations/([^/]+)/reasoningEngines/\d+", engine_resource_name)
    if not match:
        raise ValueError(f"invalid engine resource name: {engine_resource_name!r}")
    # vertexai exports Client lazily (module __getattr__), which pyright types as a module
    return vertexai.Client(project=match.group(1), location=match.group(2))  # pyright: ignore[reportCallIssue]


def usable_sandboxes(client: Any, engine_resource_name: str) -> list[Any]:
    """Running, non-expired sandboxes provisioned for the agent, the one expiring last first."""
    now = datetime.now(UTC)
    found = [
        sandbox
        for sandbox in client.agent_engines.sandboxes.list(name=engine_resource_name)
        if sandbox.display_name == SANDBOX_DISPLAY_NAME
        and sandbox.state == "STATE_RUNNING"
        and sandbox.expire_time is not None
        and sandbox.expire_time > now
    ]
    return sorted(found, key=lambda sandbox: sandbox.expire_time, reverse=True)
