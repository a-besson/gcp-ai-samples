"""Offline tests of the configuration and of the agent wiring (no LLM call)."""

import asyncio
import importlib
from types import SimpleNamespace
from typing import Any

import pytest
from anthropic import types as anthropic_types
from anthropic.lib.vertex import AsyncAnthropicVertex
from google.adk.models import Gemini
from google.adk.models.anthropic_llm import Claude
from google.adk.models.llm_request import LlmRequest
from google.genai import types
from google.genai._api_client import to_mtls_url

from config import ConfigError, load_config


def test_config_defaults_to_the_eu_multi_region() -> None:
    cfg = load_config()
    assert cfg.model == "claude-test-model"
    assert cfg.location == "eu"
    assert cfg.project == "my-gcp-project-id"


@pytest.mark.parametrize("name", ["MODEL", "GOOGLE_CLOUD_PROJECT"])
def test_config_requires_variables(monkeypatch: pytest.MonkeyPatch, name: str) -> None:
    monkeypatch.delenv(name)
    with pytest.raises(ConfigError):
        load_config()


def test_config_accepts_the_gemini_fallback(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL", "gemini-3.8-flash")
    assert load_config().model == "gemini-3.8-flash"


@pytest.mark.parametrize("model", ["gpt-4o", "llama-4-maverick", "text-bison"])
def test_config_rejects_other_model_families(monkeypatch: pytest.MonkeyPatch, model: str) -> None:
    monkeypatch.setenv("MODEL", model)
    with pytest.raises(ConfigError):
        load_config()


@pytest.mark.parametrize("location", ["eu", "europe-west1", "europe-west4", "europe-west9"])
def test_config_accepts_eu_model_locations(monkeypatch: pytest.MonkeyPatch, location: str) -> None:
    monkeypatch.setenv("MODEL_LOCATION", location)
    assert load_config().location == location


@pytest.mark.parametrize("location", ["us-central1", "us", "global", "europe-west2", "europe-west6"])
def test_config_rejects_non_eu_model_locations(monkeypatch: pytest.MonkeyPatch, location: str) -> None:
    # global has no data residency; europe-west2 (London) and europe-west6 (Zurich) are outside the EU
    monkeypatch.setenv("MODEL_LOCATION", location)
    with pytest.raises(ConfigError):
        load_config()


def test_agent_calls_claude_on_the_eu_multi_region() -> None:
    agent_module = importlib.import_module("agent")
    model = agent_module.build_agent(load_config()).model
    assert isinstance(model, Claude)
    assert model.model == "claude-test-model"
    assert model.max_tokens == agent_module.MAX_OUTPUT_TOKENS
    assert isinstance(model.client, AsyncAnthropicVertex)
    assert model.client.region == "eu"
    assert model.client.project_id == "my-gcp-project-id"
    # The eu multi-region endpoint, never the global one
    assert str(model.client.base_url).startswith("https://aiplatform.eu.rep.googleapis.com/")


def test_regional_model_location_uses_the_regional_endpoint(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL_LOCATION", "europe-west1")
    model = importlib.import_module("agent").build_agent(load_config()).model
    assert isinstance(model, Claude)
    assert isinstance(model.client, AsyncAnthropicVertex)
    assert str(model.client.base_url).startswith("https://europe-west1-aiplatform.googleapis.com/")


def test_gemini_fallback_calls_vertex_ai_on_the_eu_multi_region(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MODEL", "gemini-test-model")
    agent = importlib.import_module("agent").build_agent(load_config())
    assert isinstance(agent.model, Gemini)
    client = agent.model.api_client._api_client
    # Vertex AI in the eu multi-region, never the Gemini API (AI Studio) nor the global endpoint
    assert client.vertexai
    assert client.project == "my-gcp-project-id"
    assert client.location == "eu"
    assert client._http_options.base_url == "https://aiplatform.eu.rep.googleapis.com/"


def test_eu_multi_region_is_never_sent_to_a_missing_mtls_host() -> None:
    # Under Agent Identity google-genai switches to the mTLS endpoint; eu.rep has none, the pinned google-genai keeps
    # the multi-regional host (an older one would target aiplatform.eu.rep.mtls.googleapis.com and fail)
    assert (
        to_mtls_url("https://aiplatform.eu.rep.googleapis.com/v1/x") == "https://aiplatform.eu.rep.googleapis.com/v1/x"
    )


def test_output_tokens_are_bounded_for_both_models() -> None:
    agent = importlib.import_module("agent").build_agent(load_config())
    assert agent.generate_content_config is not None
    assert agent.generate_content_config.max_output_tokens == importlib.import_module("agent").MAX_OUTPUT_TOKENS


def test_claude_round_trip_with_the_pinned_sdk(monkeypatch: pytest.MonkeyPatch) -> None:
    # google-adk 2.10 and the pinned anthropic SDK agree on the request and response types (stubbed API call)
    agent_module = importlib.import_module("agent")
    model = agent_module.build_agent(load_config()).model
    assert isinstance(model, Claude)
    assert isinstance(model.client, AsyncAnthropicVertex)
    sent: dict[str, Any] = {}

    async def fake_create(**kwargs: Any) -> anthropic_types.Message:
        sent.update(kwargs)
        return anthropic_types.Message(
            id="msg_test",
            type="message",
            role="assistant",
            model=kwargs["model"],
            content=[anthropic_types.TextBlock(type="text", text="Brussels")],
            stop_reason="end_turn",
            stop_sequence=None,
            usage=anthropic_types.Usage(input_tokens=12, output_tokens=2),
        )

    monkeypatch.setattr(model.client.messages, "create", fake_create)
    request = LlmRequest(
        model=model.model,
        contents=[types.Content(role="user", parts=[types.Part(text="What is the capital of Belgium?")])],
        config=types.GenerateContentConfig(system_instruction=agent_module.INSTRUCTION),
    )

    async def collect() -> list[Any]:
        return [response async for response in model.generate_content_async(request)]

    responses = asyncio.run(collect())
    assert sent["model"] == "claude-test-model"
    assert sent["max_tokens"] == agent_module.MAX_OUTPUT_TOKENS
    assert sent["system"] == agent_module.INSTRUCTION
    assert responses[0].content.parts[0].text == "Brussels"
    assert responses[0].usage_metadata.prompt_token_count == 12


def test_agent_has_no_tool() -> None:
    agent = importlib.import_module("agent").build_agent(load_config())
    assert agent.name == "ingress_agent"
    assert agent.tools == []


def test_entrypoint_exposes_only_the_screened_method() -> None:
    # Model Armor screens streamQuery of ADK agents: no other method may run the agent
    agent_module = importlib.import_module("agent")
    assert agent_module.adk_app.register_operations() == {"async_stream": ["async_stream_query"]}
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
