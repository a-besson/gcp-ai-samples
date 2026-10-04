"""Offline tests: no network, no real LLM call."""

import importlib
from types import SimpleNamespace

import pytest

from config import ConfigError, load_config


@pytest.fixture(autouse=True)
def _env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL", "test-model")
    monkeypatch.delenv("MODEL_LOCATION", raising=False)


def test_config_defaults_to_an_eu_model_location() -> None:
    cfg = load_config()
    assert cfg.model == "test-model"
    assert cfg.location == "europe-west3"


def test_config_requires_model(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("MODEL")
    with pytest.raises(ConfigError):
        load_config()


@pytest.mark.parametrize("location", ["europe-west1", "europe-west3", "europe-west9"])
def test_config_accepts_eu_model_locations(monkeypatch: pytest.MonkeyPatch, location: str) -> None:
    monkeypatch.setenv("MODEL_LOCATION", location)
    assert load_config().location == location


@pytest.mark.parametrize("location", ["us-central1", "europe-west2", "europe-west6", "eu", "global"])
def test_config_rejects_non_eu_model_locations(monkeypatch: pytest.MonkeyPatch, location: str) -> None:
    # europe-west2 (London) and europe-west6 (Zurich) are outside the EU; "eu" has no mTLS host
    monkeypatch.setenv("MODEL_LOCATION", location)
    with pytest.raises(ConfigError):
        load_config()


def test_model_client_uses_the_model_location(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL_LOCATION", "europe-west9")
    agent_module = importlib.import_module("agent")
    assert agent_module.build_agent(load_config()).model.client_kwargs == {"location": "europe-west9"}


def test_root_agent_is_built_without_calling_the_llm() -> None:
    agent_module = importlib.import_module("agent")
    agent = agent_module.build_agent(load_config())
    assert agent.name == "simple_agent"
    assert agent.tools == []
    assert agent_module.root_agent.name == "simple_agent"
    # Agent Runtime needs an object exposing query methods, not a bare LlmAgent
    assert callable(agent_module.adk_app.async_stream_query)


def test_after_model_logs_usage(caplog: pytest.LogCaptureFixture) -> None:
    agent_module = importlib.import_module("agent")
    ctx = SimpleNamespace(invocation_id="inv-1")
    usage = SimpleNamespace(prompt_token_count=3, candidates_token_count=5, total_token_count=8)
    agent_module.logger.propagate = True
    with caplog.at_level("INFO", logger="agent"):
        agent_module._before_model(ctx, None)
        agent_module._after_model(ctx, SimpleNamespace(usage_metadata=usage))
    assert "total_tokens=8" in caplog.text
    assert "duration_ms=" in caplog.text
