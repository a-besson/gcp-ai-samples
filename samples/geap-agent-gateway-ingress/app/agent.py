"""ADK agent answering with Claude on Vertex AI, served behind an ingress Agent Gateway (Model Armor).

Gemini is a temporary fallback (MODEL=gemini-*) while the project has no Claude quota.
"""

import time
from typing import Any

from anthropic.lib.vertex import AsyncAnthropicVertex
from google.adk.agents import LlmAgent
from google.adk.models import BaseLlm, Gemini
from google.adk.models.anthropic_llm import Claude
from google.genai import types
from vertexai.agent_engines import AdkApp

from config import Config, load_config
from logger import get_logger

logger = get_logger("agent")

INSTRUCTION = "You are a concise assistant. Answer the user's question in a few sentences."
# Upper bound of one answer, to bound the cost of a call
MAX_OUTPUT_TOKENS = 1024

# Start time of each in-flight model call, keyed by invocation, to log its duration.
_started: dict[str, float] = {}


def _before_model(callback_context: Any, llm_request: Any) -> None:
    _started[callback_context.invocation_id] = time.monotonic()


def _after_model(callback_context: Any, llm_response: Any) -> None:
    """Log token usage and duration of every LLM call."""
    started = _started.pop(callback_context.invocation_id, None)
    duration_ms = int((time.monotonic() - started) * 1000) if started is not None else -1
    usage = getattr(llm_response, "usage_metadata", None)
    logger.info(
        "llm_call duration_ms=%d prompt_tokens=%s output_tokens=%s total_tokens=%s",
        duration_ms,
        getattr(usage, "prompt_token_count", None),
        getattr(usage, "candidates_token_count", None),
        getattr(usage, "total_token_count", None),
    )


def build_model(config: Config) -> BaseLlm:
    """Model client in the EU model location, independent of the engine region; transient errors (429, 5xx) are
    retried by the client."""
    if config.model.startswith("gemini-"):
        return Gemini(
            model=config.model,
            # Explicit Vertex AI target: without it google-genai would fall back to the Gemini API (AI Studio)
            client_kwargs={"vertexai": True, "project": config.project, "location": config.location},
            retry_options=types.HttpRetryOptions(attempts=3, initial_delay=1.0, max_delay=10.0, exp_base=2.0),
        )
    return Claude(
        model=config.model,
        max_tokens=MAX_OUTPUT_TOKENS,
        client=AsyncAnthropicVertex(project_id=config.project, region=config.location, max_retries=3, timeout=60.0),
    )


def build_agent(config: Config) -> LlmAgent:
    """Build the agent, without tools."""
    return LlmAgent(
        name="ingress_agent",
        description="Answers simple questions.",
        model=build_model(config),
        instruction=INSTRUCTION,
        # Same bound on the Gemini path (thinking tokens included); Claude reads its own max_tokens
        generate_content_config=types.GenerateContentConfig(max_output_tokens=MAX_OUTPUT_TOKENS),
        before_model_callback=_before_model,
        after_model_callback=_after_model,
    )


class ScreenedAdkApp(AdkApp):
    """AdkApp exposing a single method: async_stream_query.

    Model Armor screens client-to-agent traffic for reasoningEngines.streamQuery requests of ADK agents only. The
    other AdkApp methods that run the agent (stream_query, streaming_agent_run_with_events) would be ways to reach
    the model without that screening, and the session methods are not needed by the clients of this sample.
    """

    def register_operations(self) -> dict[str, list[str]]:
        return {"async_stream": ["async_stream_query"]}


# `root_agent` is what ADK tooling (adk web, evals) loads.
root_agent = build_agent(load_config())

# Agent Runtime serves an object that exposes query methods: a bare LlmAgent fails to start. This is the
# entrypoint of the Terraform python_spec.
adk_app = ScreenedAdkApp(agent=root_agent)
