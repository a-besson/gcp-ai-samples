"""Offline tests of the tools: GCS and HTTP are mocked, retries run without sleeping."""

from unittest.mock import MagicMock

import pytest
import requests

import tools
from tools import PathError, resolve_workspace_path


@pytest.mark.parametrize(
    "path",
    [
        "",
        "/etc/passwd",
        "../secret.txt",
        "agent-workspace/../secret.txt",
        "secret/x.txt",
        "agent-workspace",
        "a\\b",
        "agent-workspace/\x00",
    ],
)
def test_resolve_rejects_paths_outside_the_workspace(path: str) -> None:
    with pytest.raises(PathError):
        resolve_workspace_path(path)


def test_resolve_accepts_and_normalises_workspace_paths() -> None:
    assert resolve_workspace_path("agent-workspace/a//b/./c.txt") == "agent-workspace/a/b/c.txt"


def test_write_outside_workspace_never_reaches_gcs(mocker) -> None:
    client = mocker.patch.object(tools.storage, "Client")
    result = tools.write_workspace_file("secret/x.txt", "data")
    assert result["status"] == "error"
    client.assert_not_called()


def test_write_and_read_roundtrip(mocker) -> None:
    bucket = MagicMock()
    mocker.patch.object(tools.storage, "Client").return_value.bucket.return_value = bucket
    assert tools.write_workspace_file("agent-workspace/hello.txt", "hello")["status"] == "ok"
    bucket.blob.assert_called_once_with("agent-workspace/hello.txt")
    bucket.blob.return_value.upload_from_string.assert_called_once()

    blob = MagicMock(size=5)
    blob.download_as_text.return_value = "hello"
    bucket.get_blob.return_value = blob
    assert tools.read_workspace_file("agent-workspace/hello.txt") == {
        "status": "ok",
        "path": "agent-workspace/hello.txt",
        "content": "hello",
    }


def test_write_rejects_oversized_content(mocker) -> None:
    mocker.patch.object(tools.storage, "Client")
    result = tools.write_workspace_file("agent-workspace/big.txt", "x" * (tools.MAX_FILE_BYTES + 1))
    assert result["status"] == "error"


@pytest.fixture
def no_sleep(mocker) -> None:
    mocker.patch("tenacity.nap.time.sleep")
    mocker.patch.object(tools.id_token, "fetch_id_token", return_value="token")


def _response(status: int) -> MagicMock:
    response = MagicMock(status_code=status)
    response.json.return_value = {"ok": True}
    response.raise_for_status.side_effect = requests.HTTPError(f"HTTP {status}") if status >= 400 else None
    return response


def test_trigger_retries_on_503_then_succeeds(mocker, no_sleep) -> None:
    post = mocker.patch.object(tools.requests, "post", side_effect=[_response(503), _response(200)])
    result = tools.trigger_action({"hello": "world"})
    assert result == {"status": "ok", "response": {"ok": True}}
    assert post.call_count == 2


def test_trigger_does_not_retry_on_403(mocker, no_sleep) -> None:
    post = mocker.patch.object(tools.requests, "post", return_value=_response(403))
    result = tools.trigger_action({"hello": "world"})
    assert result["status"] == "error"
    assert post.call_count == 1


def test_trigger_gives_up_after_three_transient_failures(mocker, no_sleep) -> None:
    post = mocker.patch.object(tools.requests, "post", return_value=_response(503))
    assert tools.trigger_action({"a": 1})["status"] == "error"
    assert post.call_count == 3


def test_trigger_rejects_large_payload(mocker) -> None:
    post = mocker.patch.object(tools.requests, "post")
    assert tools.trigger_action({"data": "x" * 2000})["status"] == "error"
    post.assert_not_called()
