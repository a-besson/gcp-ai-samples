"""Offline tests: no network, no real LLM call."""

import importlib
from types import SimpleNamespace

import pytest

from config import ConfigError, load_config


@pytest.fixture(autouse=True)
def _env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL", "test-model")
    monkeypatch.delenv("MODEL_LOCATION", raising=False)


def test_config_defaults_to_belgium() -> None:
    cfg = load_config()
    assert cfg.model == "test-model"
    assert cfg.location == "europe-west1"


def test_config_requires_model(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("MODEL")
    with pytest.raises(ConfigError):
        load_config()


def test_config_rejects_other_regions(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL_LOCATION", "us-central1")
    with pytest.raises(ConfigError):
        load_config()


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
