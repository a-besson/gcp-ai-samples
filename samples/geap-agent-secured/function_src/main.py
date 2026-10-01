"""Cloud Run function (gen2) triggered by the agent: validates a small JSON payload and acknowledges it."""

import json
import logging
from datetime import UTC, datetime

import functions_framework

logger = logging.getLogger("fn-agent-action")
logging.basicConfig(level=logging.INFO)

MAX_PAYLOAD_BYTES = 1_000


@functions_framework.http
def handle(request):
    """Acknowledge a JSON payload sent by the agent; authentication is enforced by Cloud Run IAM."""
    if request.method != "POST":
        return ("method not allowed", 405)
    body = request.get_data()
    if len(body) > MAX_PAYLOAD_BYTES:
        return ("payload too large", 413)
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return ("invalid JSON", 400)
    if not isinstance(payload, dict):
        return ("payload must be a JSON object", 400)

    logger.info("action received keys=%s", sorted(payload))
    return {"status": "accepted", "received_keys": sorted(payload), "at": datetime.now(UTC).isoformat()}
