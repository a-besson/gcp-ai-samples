"""Dummy configuration injected for every offline test: no real credentials, no network.

The e2e tests (marker `e2e`) are left alone: they call the deployed agent with the caller's credentials.
"""

import google.auth
import pytest
from google.auth.credentials import AnonymousCredentials


def _offline(request: pytest.FixtureRequest) -> bool:
    return request.node.get_closest_marker("e2e") is None


@pytest.fixture(autouse=True)
def _env(request: pytest.FixtureRequest, monkeypatch: pytest.MonkeyPatch) -> None:
    if not _offline(request):
        return
    monkeypatch.setenv("MODEL", "claude-test-model")
    monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "my-gcp-project-id")
    monkeypatch.delenv("MODEL_LOCATION", raising=False)


@pytest.fixture(autouse=True)
def _adc(request: pytest.FixtureRequest, monkeypatch: pytest.MonkeyPatch) -> None:
    """Offline Application Default Credentials: the clients resolve them when they are built."""
    if not _offline(request):
        return
    monkeypatch.setattr(google.auth, "default", lambda *_, **__: (AnonymousCredentials(), "test-project"))
