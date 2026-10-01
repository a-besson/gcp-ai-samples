# 003 — Model Armor enforced at the Agent Gateway
**Date:** 2026-10-01 | **Status:** accepted

## Context
User input and agent output must be screened. Model Armor can be called from agent code or enforced by the gateway (authz extension + `CONTENT_AUTHZ` authz policy).

## Decision
Enforce Model Armor on the `CLIENT_TO_AGENT` gateway, fully in Terraform (`google_network_services_authz_extension` with service `modelarmor.europe-west1.rep.googleapis.com`, `google_network_security_authz_policy`). Fallback: ADK before/after-model callbacks calling the regional Model Armor API.

## Consequences
No application code for guardrails. On the ingress gateway, semantic governance cannot be combined with Model Armor, so it is attached to the egress gateway only.
