# 006 — Claude on Agent Runtime behind a Model Armor ingress gateway
**Date:** 2026-10-25 | **Status:** accepted

## Context
`geap-agent-gateway-ingress` serves an ADK agent that answers with Claude Haiku 5.5 (Vertex AI partner model), behind a `CLIENT_TO_AGENT` Agent Gateway where Model Armor must stop prompt injections. Three facts shape it:

- Agent Identity tokens are bound to the agent certificate by default (`google-auth` requests a certificate-bound token when `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES` is unset). `google-genai` then calls the mTLS endpoints; the Anthropic SDK, used by ADK's `Claude` model, calls the standard endpoints and presents no client certificate.
- On the ingress path, Model Armor only screens `reasoningEngines.streamQuery` requests and responses of ADK agents (Model Armor / Agent Gateway integration documentation). `AdkApp` also registers `stream_query` and `streaming_agent_run_with_events`, which run the agent too, the latter with a different payload shape.
- The ingress callout to Model Armor is made by the Agent Runtime service agent, which needs `roles/modelarmor.calloutUser` and `roles/modelarmor.user`.

## Decision
- The agent gets **unbound Agent Identity tokens** (`GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=false`, as in the Agent Gateway documentation and the ingress codelab), and calls Claude through ADK's `Claude` with an explicit `AsyncAnthropicVertex` client whose region is `model_location` (an EU region or the `eu` multi-region).
- The entrypoint is an `AdkApp` subclass that **registers `async_stream_query` only**: the one method Model Armor screens is the only way to run the agent.
- Model Armor is **fail closed**, templates are `INSPECT_AND_BLOCK`, and sanitization verdicts are logged.
- The sample owns the Model Armor roles of the Agent Runtime service agent.

## Consequences
- An unbound token is a bearer token: if it leaked from the runtime, it could be replayed from elsewhere until it expires. Accepted for a sample that holds two roles (`aiplatform.user`, `logging.logWriter`). A stricter option, not taken: an mTLS `httpx` client built from the agent certificate and the regional mTLS host (`<region>-aiplatform.mtls.googleapis.com`). This option is undocumented for the Anthropic SDK and impossible with `eu`, the default `model_location`, which has no mTLS host.
- Clients that need sessions or other `AdkApp` methods cannot call them on this engine; the e2e suite reads sessions through the Agent Runtime sessions API instead.
- The Model Armor roles are bound to a service agent shared by every engine of the project: another stack binding the same roles would remove them from this one on destroy.
- The e2e suite proves a block happened at the gateway (gateway `403` Model Armor error, no session, `BLOCK` verdict in the Model Armor log), not only that the model refused.
- Temporary fallback (2026-10-25): while the project has no Claude quota, `model = gemini-*` selects ADK's `Gemini` on Vertex AI in the same `model_location`. On `eu`, the pinned `google-genai` (2.33) keeps the multi-regional host, which has no mTLS endpoint, so the fallback relies on the same unbound tokens. The gateway, the screening and this decision are unchanged; Claude stays the default.
