"""Environment configuration, validated before the agent is built."""

import os
from dataclasses import dataclass

# Sovereignty: the agent stays in Belgium (Terraform var.region); the model is called in the EU only.
# The "eu" multi-region (aiplatform.eu.rep.googleapis.com) is allowed here, unlike in the other Gemini samples: the
# Anthropic client does not use mTLS, and google-genai (>= 2.33) keeps multi-regional hosts off the missing eu mTLS
# host. Both rely on unbound Agent Identity tokens (Terraform env).
EU_MODEL_LOCATIONS = frozenset(
    {
        "eu",  # EU multi-region endpoint
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
# EU multi-region: Google keeps the ML processing within the EU and routes across its EU regions
DEFAULT_MODEL_LOCATION = "eu"
# Claude is the model of this sample; Gemini is a temporary fallback while the project has no Claude quota.
MODEL_PREFIXES = ("claude-", "gemini-")


class ConfigError(ValueError):
    """Raised when the environment configuration is invalid."""


@dataclass(frozen=True)
class Config:
    model: str
    location: str
    # Project billed for the Claude calls (set by Agent Runtime)
    project: str


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ConfigError(f"{name} environment variable is required")
    return value


def load_config() -> Config:
    """Read and validate the configuration."""
    model = _required("MODEL")
    if not model.startswith(MODEL_PREFIXES):
        raise ConfigError(f"MODEL must be a Claude (or fallback Gemini) model on Vertex AI, got {model!r}")

    location = os.environ.get("MODEL_LOCATION", DEFAULT_MODEL_LOCATION).strip()
    if location not in EU_MODEL_LOCATIONS:
        raise ConfigError(f"MODEL_LOCATION must be an EU location, got {location!r}")

    # The model location is passed to the model client only: GOOGLE_CLOUD_LOCATION stays the engine region
    # (sessions, telemetry).
    return Config(model=model, location=location, project=_required("GOOGLE_CLOUD_PROJECT"))
