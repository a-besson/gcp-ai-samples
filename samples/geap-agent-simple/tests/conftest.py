"""Offline test configuration: no real credentials, no network."""

import google.auth
import pytest
from google.auth.credentials import AnonymousCredentials


@pytest.fixture(autouse=True)
def _adc(monkeypatch: pytest.MonkeyPatch) -> None:
    """Offline Application Default Credentials: the GenAI client resolves them when it is built."""
    monkeypatch.setattr(google.auth, "default", lambda *_, **__: (AnonymousCredentials(), "test-project"))
