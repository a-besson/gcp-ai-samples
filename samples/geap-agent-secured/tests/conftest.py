"""Dummy configuration injected for every test: no real credentials, no network."""

import google.auth
import pytest
from google.auth.credentials import AnonymousCredentials


@pytest.fixture(autouse=True)
def _env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL", "test-model")
    monkeypatch.setenv("BUCKET", "test-bucket")
    monkeypatch.setenv("FUNCTION_URL", "https://fn.example.test")
    monkeypatch.delenv("MODEL_LOCATION", raising=False)
    monkeypatch.delenv("AGENT_ENGINE_RESOURCE_NAME", raising=False)
    monkeypatch.delenv("GOOGLE_CLOUD_AGENT_ENGINE_ID", raising=False)
    monkeypatch.delenv("GOOGLE_CLOUD_PROJECT", raising=False)
    monkeypatch.delenv("ENGINE_LOCATION", raising=False)


@pytest.fixture(autouse=True)
def _adc(monkeypatch: pytest.MonkeyPatch) -> None:
    """Offline Application Default Credentials: the GenAI client resolves them when it is built."""
    monkeypatch.setattr(google.auth, "default", lambda *_, **__: (AnonymousCredentials(), "test-project"))
