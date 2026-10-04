"""Environment configuration, validated before the agent is built."""

import os
from dataclasses import dataclass

# Sovereignty: the agent stays in Belgium (Terraform var.region); model calls stay in an EU region.
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


class ConfigError(ValueError):
    """Raised when the environment configuration is invalid."""


@dataclass(frozen=True)
class Config:
    model: str
    location: str


def load_config() -> Config:
    """Read and validate the configuration; export what the Vertex AI client expects."""
    model = os.environ.get("MODEL", "").strip()
    if not model:
        raise ConfigError("MODEL environment variable is required (e.g. a Gemini model name)")

    location = os.environ.get("MODEL_LOCATION", DEFAULT_MODEL_LOCATION).strip()
    if location not in EU_MODEL_LOCATIONS:
        raise ConfigError(f"MODEL_LOCATION must be an EU region, got {location!r}")

    # The google-genai client reads this variable; Agent Runtime may already set it. The model location is
    # passed to the model client only: GOOGLE_CLOUD_LOCATION stays the engine region (sessions, telemetry).
    os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "true")
    return Config(model=model, location=location)
