"""Environment configuration, validated before the agent is built."""

import os
from dataclasses import dataclass

# Sovereignty: model calls must stay on the Belgium regional endpoint.
ALLOWED_LOCATION = "europe-west1"


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

    location = os.environ.get("MODEL_LOCATION", ALLOWED_LOCATION).strip()
    if location != ALLOWED_LOCATION:
        raise ConfigError(f"MODEL_LOCATION must be {ALLOWED_LOCATION}, got {location!r}")

    # The google-genai client reads these variables; Agent Runtime may already set them.
    os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "true")
    os.environ["GOOGLE_CLOUD_LOCATION"] = location
    return Config(model=model, location=location)
