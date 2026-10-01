"""Offline tests of the configuration and of the agent wiring (no LLM call)."""

import importlib
from types import SimpleNamespace

import pytest

from config import ConfigError, load_config


def test_config_defaults_to_belgium() -> None:
    cfg = load_config()
    assert cfg.location == "europe-west1"
    assert cfg.bucket == "test-bucket"
    assert cfg.engine_resource_name is None


@pytest.mark.parametrize("name", ["MODEL", "BUCKET", "FUNCTION_URL"])
def test_config_requires_variables(monkeypatch: pytest.MonkeyPatch, name: str) -> None:
    monkeypatch.delenv(name)
    with pytest.raises(ConfigError):
        load_config()


def test_config_rejects_other_regions_and_http_urls(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL_LOCATION", "us-central1")
    with pytest.raises(ConfigError):
        load_config()
    monkeypatch.delenv("MODEL_LOCATION")
    monkeypatch.setenv("FUNCTION_URL", "http://insecure.example.test")
    with pytest.raises(ConfigError):
        load_config()


def test_engine_resource_name_from_runtime_variables(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_CLOUD_AGENT_ENGINE_ID", "123")
    monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "my-gcp-project-id")
    assert load_config().engine_resource_name == (
        "projects/my-gcp-project-id/locations/europe-west1/reasoningEngines/123"
    )


def test_agent_has_the_three_tools_and_no_sandbox_without_engine() -> None:
    agent_module = importlib.import_module("agent")
    agent = agent_module.build_agent(load_config())
    assert [t.__name__ for t in agent.tools] == ["read_workspace_file", "write_workspace_file", "trigger_action"]
    assert agent.code_executor is None


def test_entrypoint_exposes_query_methods() -> None:
    # Agent Runtime refuses a bare LlmAgent: the entrypoint must be an AdkApp
    agent_module = importlib.import_module("agent")
    assert callable(agent_module.adk_app.async_stream_query)
    assert callable(agent_module.adk_app.stream_query)


def test_agent_attaches_sandbox_when_engine_is_known(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_ENGINE_RESOURCE_NAME", "projects/p/locations/europe-west1/reasoningEngines/1")
    agent_module = importlib.import_module("agent")
    agent = agent_module.build_agent(load_config())
    assert agent.code_executor is not None


def test_after_model_logs_usage(caplog: pytest.LogCaptureFixture) -> None:
    agent_module = importlib.import_module("agent")
    ctx = SimpleNamespace(invocation_id="inv-1")
    usage = SimpleNamespace(prompt_token_count=3, candidates_token_count=5, total_token_count=8)
    agent_module.logger.propagate = True
    with caplog.at_level("INFO", logger="agent"):
        agent_module._before_model(ctx, None)
        agent_module._after_model(ctx, SimpleNamespace(usage_metadata=usage))
    assert "total_tokens=8" in caplog.text
