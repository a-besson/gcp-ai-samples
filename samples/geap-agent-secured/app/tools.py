"""Function tools of the secured agent: scoped bucket access and the Cloud Run function trigger.

Path scoping here is defence in depth: the real barrier is the IAM binding on the
`agent-workspace/` managed folder, which denies every other object.
"""

import os
import posixpath
from typing import Any

import google.auth.transport.requests
import requests
from google.cloud import storage
from google.oauth2 import id_token
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from config import WORKSPACE_PREFIX
from logger import get_logger

logger = get_logger("tools")

MAX_FILE_BYTES = 100_000
MAX_PAYLOAD_BYTES = 1_000
HTTP_TIMEOUT_SECONDS = 10


class PathError(ValueError):
    """The requested object path is outside the allowed workspace."""


class TransientError(Exception):
    """A failure worth retrying (network error, timeout, HTTP 5xx / 429)."""


def resolve_workspace_path(path: str) -> str:
    """Return the normalised object name, or raise PathError if it leaves `agent-workspace/`."""
    if not path or "\x00" in path or "\\" in path or path.startswith("/"):
        raise PathError("path must be a relative object path under agent-workspace/")
    if ".." in path.split("/"):
        raise PathError("path traversal is not allowed")
    normalised = posixpath.normpath(path)
    if not normalised.startswith(WORKSPACE_PREFIX) or normalised == WORKSPACE_PREFIX.rstrip("/"):
        raise PathError(f"path must start with {WORKSPACE_PREFIX}")
    return normalised


def _bucket() -> storage.Bucket:
    return storage.Client().bucket(os.environ["BUCKET"])


def read_workspace_file(path: str) -> dict[str, Any]:
    """Read a text file from the agent workspace.

    Args:
        path: Object path inside the workspace, e.g. "agent-workspace/notes/todo.txt".

    Returns:
        A dict with status "ok" and the file content, or status "error" and a message.
    """
    try:
        name = resolve_workspace_path(path)
        blob = _bucket().get_blob(name)
        if blob is None:
            return {"status": "error", "message": f"{name} does not exist"}
        if (blob.size or 0) > MAX_FILE_BYTES:
            return {"status": "error", "message": f"{name} is larger than {MAX_FILE_BYTES} bytes"}
        return {"status": "ok", "path": name, "content": blob.download_as_text()}
    except PathError as exc:
        return {"status": "error", "message": str(exc)}


def write_workspace_file(path: str, content: str) -> dict[str, Any]:
    """Write a text file in the agent workspace (overwrites an existing file).

    Args:
        path: Object path inside the workspace, e.g. "agent-workspace/reports/result.txt".
        content: Text to store (at most 100 kB).

    Returns:
        A dict with status "ok" and the written path, or status "error" and a message.
    """
    try:
        name = resolve_workspace_path(path)
        if len(content.encode()) > MAX_FILE_BYTES:
            return {"status": "error", "message": f"content is larger than {MAX_FILE_BYTES} bytes"}
        _bucket().blob(name).upload_from_string(content, content_type="text/plain; charset=utf-8")
        return {"status": "ok", "path": name}
    except PathError as exc:
        return {"status": "error", "message": str(exc)}


@retry(
    retry=retry_if_exception_type(TransientError),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    reraise=True,
)
def _post_to_function(url: str, payload: dict[str, Any]) -> dict[str, Any]:
    token = id_token.fetch_id_token(google.auth.transport.requests.Request(), url)
    try:
        response = requests.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
            timeout=HTTP_TIMEOUT_SECONDS,
        )
    except (requests.ConnectionError, requests.Timeout) as exc:
        raise TransientError(str(exc)) from exc
    if response.status_code >= 500 or response.status_code == 429:
        raise TransientError(f"HTTP {response.status_code}")
    response.raise_for_status()  # other 4xx (e.g. 403) are definitive: no retry
    return response.json()


def trigger_action(payload: dict[str, Any]) -> dict[str, Any]:
    """Trigger the Cloud Run function with a small JSON payload.

    Args:
        payload: JSON object (at most 1 kB once serialised).

    Returns:
        A dict with status "ok" and the function response, or status "error" and a message.
    """
    import json

    if len(json.dumps(payload).encode()) > MAX_PAYLOAD_BYTES:
        return {"status": "error", "message": f"payload is larger than {MAX_PAYLOAD_BYTES} bytes"}
    try:
        return {"status": "ok", "response": _post_to_function(os.environ["FUNCTION_URL"], payload)}
    except Exception as exc:  # tools must never raise into the LLM loop
        logger.warning("trigger_action failed: %s", exc)
        return {"status": "error", "message": f"function call failed: {type(exc).__name__}"}
