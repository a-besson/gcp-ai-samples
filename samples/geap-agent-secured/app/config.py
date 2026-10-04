"""Environment configuration, validated before the agent is built."""

import os
from dataclasses import dataclass

# Sovereignty: resources stay in Belgium (Terraform var.region); model calls stay in an EU region.
# The "eu" multi-region is left out: under Agent Identity mTLS, google-genai targets
# aiplatform.eu.rep.mtls.googleapis.com, which does not exist.
EU_MODEL_LOCATIONS = frozenset(
    {
        "europe-central2",  # Warsaw
        "europe-north1",  # Finland
        "europe-north2",  # Stockholm
        "europe-southwest1",  # Madrid
        "europe-west1",  # Belgium
        "europe-west3",  # Frankfurt
        "europe-west4",  # Netherlands
        "europe-west8",  # Milan
        "europe-west9",  # Paris
        "europe-west10",  # Berlin
        "europe-west12",  # Turin
    }
)
# Closest EU region serving gemini-3.5-flash (europe-west1 does not serve gemini-3.x)
DEFAULT_MODEL_LOCATION = "europe-west3"
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


def _engine_resource_name() -> str | None:
    """Resolve the engine that hosts sandboxes: explicit override, else injected by Agent Runtime."""
    explicit = os.environ.get("AGENT_ENGINE_RESOURCE_NAME", "").strip()
    if explicit:
        return explicit
    engine_id = os.environ.get("GOOGLE_CLOUD_AGENT_ENGINE_ID", "").strip()
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "").strip()
    # The engine region (set by Terraform), which may differ from the model location
    location = os.environ.get("ENGINE_LOCATION", "").strip()
    if engine_id and project and location:
        return f"projects/{project}/locations/{location}/reasoningEngines/{engine_id}"
    return None


def load_config() -> Config:
    """Read and validate the configuration; export what the Vertex AI client expects."""
    location = os.environ.get("MODEL_LOCATION", DEFAULT_MODEL_LOCATION).strip()
    if location not in EU_MODEL_LOCATIONS:
        raise ConfigError(f"MODEL_LOCATION must be an EU region, got {location!r}")

    function_url = _required("FUNCTION_URL")
    if not function_url.startswith("https://"):
        raise ConfigError("FUNCTION_URL must be an https:// URL")

    # The google-genai client reads this variable; Agent Runtime may already set it. The model location is
    # passed to the model client only: GOOGLE_CLOUD_LOCATION stays the engine region (sessions, telemetry).
    os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "true")
    return Config(
        model=_required("MODEL"),
        location=location,
        bucket=_required("BUCKET"),
        function_url=function_url,
        engine_resource_name=_engine_resource_name(),
    )
