"""Environment configuration, validated before the agent is built."""

import os
from dataclasses import dataclass

# Sovereignty: model calls must stay on the Belgium regional endpoint.
ALLOWED_LOCATION = "europe-west1"
# The only bucket path the agent may touch (also enforced by IAM on a managed folder).
WORKSPACE_PREFIX = "agent-workspace/"


class ConfigError(ValueError):
    """Raised when the environment configuration is invalid."""


@dataclass(frozen=True)
class Config:
    model: str
    location: str
    bucket: str
    function_url: str
    # Agent Runtime engine hosting the code-execution sandboxes (None disables code execution)
    engine_resource_name: str | None


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ConfigError(f"{name} environment variable is required")
    return value


def _engine_resource_name(location: str) -> str | None:
    """Resolve the engine that hosts sandboxes: explicit override, else injected by Agent Runtime."""
    explicit = os.environ.get("AGENT_ENGINE_RESOURCE_NAME", "").strip()
    if explicit:
        return explicit
    engine_id = os.environ.get("GOOGLE_CLOUD_AGENT_ENGINE_ID", "").strip()
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "").strip()
    if engine_id and project:
        return f"projects/{project}/locations/{location}/reasoningEngines/{engine_id}"
    return None


def load_config() -> Config:
    """Read and validate the configuration; export what the Vertex AI client expects."""
    location = os.environ.get("MODEL_LOCATION", ALLOWED_LOCATION).strip()
    if location != ALLOWED_LOCATION:
        raise ConfigError(f"MODEL_LOCATION must be {ALLOWED_LOCATION}, got {location!r}")

    function_url = _required("FUNCTION_URL")
    if not function_url.startswith("https://"):
        raise ConfigError("FUNCTION_URL must be an https:// URL")

    # The google-genai client reads these variables; Agent Runtime may already set them.
    os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "true")
    os.environ["GOOGLE_CLOUD_LOCATION"] = location
    return Config(
        model=_required("MODEL"),
        location=location,
        bucket=_required("BUCKET"),
        function_url=function_url,
        engine_resource_name=_engine_resource_name(location),
    )
