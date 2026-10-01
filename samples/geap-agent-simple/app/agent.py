"""Simple ADK agent: answers a question with an LLM call, no tool."""

import time
from typing import Any

from google.adk.agents import LlmAgent
from google.adk.models import Gemini
from google.genai import types

from config import Config, load_config
from logger import get_logger

logger = get_logger("agent")

INSTRUCTION = "You are a concise assistant. Answer the user's question in a few sentences."

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


def build_agent(config: Config) -> LlmAgent:
    """Build the agent; transient model errors are retried by the client."""
    model = Gemini(
        model=config.model,
        retry_options=types.HttpRetryOptions(attempts=3, initial_delay=1.0, max_delay=10.0, exp_base=2.0),
    )
    return LlmAgent(
        name="simple_agent",
        description="Answers simple questions.",
        model=model,
        instruction=INSTRUCTION,
        before_model_callback=_before_model,
        after_model_callback=_after_model,
    )


# Entrypoint object referenced by the Terraform python_spec (entrypoint_object = "root_agent")
root_agent = build_agent(load_config())
