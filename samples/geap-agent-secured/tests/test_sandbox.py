"""Offline tests of the pre-provisioned sandbox: lookup, agent callback and provisioning script (fake client)."""

import importlib
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any

import pytest
from scripts import provision_sandbox

from config import load_config
from sandbox import SANDBOX_DISPLAY_NAME, client_for, usable_sandboxes

ENGINE = "projects/my-gcp-project-id/locations/europe-west1/reasoningEngines/1"


def _sandbox(sandbox_id: str, days_left: float, display_name: str = SANDBOX_DISPLAY_NAME, state: str = "STATE_RUNNING"):
    return SimpleNamespace(
        name=f"{ENGINE}/sandboxEnvironments/{sandbox_id}",
        display_name=display_name,
        state=state,
        expire_time=datetime.now(UTC) + timedelta(days=days_left),
    )


class FakeSandboxes:
    """Stands for client.agent_engines.sandboxes: creation adds a sandbox that runs code at once."""

    def __init__(self, items: list[Any]) -> None:
        self.items = items
        self.created: list[dict[str, Any]] = []
        self.deleted: list[str] = []

    def list(self, name: str) -> list[Any]:
        return list(self.items)

    def create(self, name: str, spec: dict[str, Any], config: dict[str, Any]) -> None:
        self.created.append(config)
        self.items.append(_sandbox("new", days_left=7))

    def execute_code(self, name: str, input_data: dict[str, Any]) -> Any:
        return SimpleNamespace(outputs=[SimpleNamespace(data=b'{"msg_out": "42\\n"}')])

    def delete(self, name: str) -> None:
        self.deleted.append(name)


def _client(items: list[Any]) -> Any:
    return SimpleNamespace(agent_engines=SimpleNamespace(sandboxes=FakeSandboxes(items)))


def test_usable_sandboxes_keeps_running_unexpired_ones_of_the_agent() -> None:
    client = _client(
        [
            _sandbox("short", days_left=1),
            _sandbox("other", days_left=5, display_name="default_sandbox"),
            _sandbox("expired", days_left=-1),
            _sandbox("stopped", days_left=5, state="STATE_STOPPED"),
            _sandbox("long", days_left=6),
        ]
    )
    names = [s.name.rsplit("/", 1)[-1] for s in usable_sandboxes(client, ENGINE)]
    assert names == ["long", "short"]


def test_client_for_rejects_a_non_engine_name() -> None:
    with pytest.raises(ValueError, match="invalid engine resource name"):
        client_for(f"{ENGINE}/sandboxEnvironments/2")


def test_agent_uses_the_provisioned_sandbox(monkeypatch: pytest.MonkeyPatch) -> None:
    agent_module = importlib.import_module("agent")
    monkeypatch.setattr(agent_module, "client_for", lambda _: _client([_sandbox("ready", days_left=6)]))
    context = SimpleNamespace(state={})
    agent_module._use_provisioned_sandbox(ENGINE)(context)
    assert context.state["sandbox_name"] == f"{ENGINE}/sandboxEnvironments/ready"


def test_agent_leaves_the_executor_fallback_when_no_sandbox(monkeypatch: pytest.MonkeyPatch) -> None:
    agent_module = importlib.import_module("agent")
    monkeypatch.setattr(agent_module, "client_for", lambda _: _client([]))
    context = SimpleNamespace(state={})
    agent_module._use_provisioned_sandbox(ENGINE)(context)
    assert "sandbox_name" not in context.state


def test_agent_survives_a_lookup_error(monkeypatch: pytest.MonkeyPatch) -> None:
    agent_module = importlib.import_module("agent")

    def broken(_: str) -> Any:
        raise RuntimeError("egress denied")

    monkeypatch.setattr(agent_module, "client_for", broken)
    context = SimpleNamespace(state={})
    agent_module._use_provisioned_sandbox(ENGINE)(context)
    assert context.state == {}


def test_agent_looks_up_the_sandbox_only_when_engine_is_known(monkeypatch: pytest.MonkeyPatch) -> None:
    agent_module = importlib.import_module("agent")
    assert agent_module.build_agent(load_config()).before_agent_callback is None
    monkeypatch.setenv("AGENT_ENGINE_RESOURCE_NAME", ENGINE)
    assert agent_module.build_agent(load_config()).before_agent_callback is not None


def test_provision_reuses_a_sandbox_far_from_expiry() -> None:
    client = _client([_sandbox("ready", days_left=6)])
    assert provision_sandbox.provision(client, ENGINE) == f"{ENGINE}/sandboxEnvironments/ready"
    assert client.agent_engines.sandboxes.created == []


def test_provision_renews_without_waiting_for_the_creation_operation() -> None:
    client = _client([_sandbox("old", days_left=0.5)])
    assert provision_sandbox.provision(client, ENGINE) == f"{ENGINE}/sandboxEnvironments/new"
    sandboxes = client.agent_engines.sandboxes
    assert sandboxes.created[0]["wait_for_completion"] is False
    assert sandboxes.created[0]["display_name"] == SANDBOX_DISPLAY_NAME
    assert sandboxes.deleted == [f"{ENGINE}/sandboxEnvironments/old"]
