# 004 — Two Agent Gateways (ingress and egress)
**Date:** 2026-10-01 | **Status:** accepted

## Context
`governed_access_path` is either `CLIENT_TO_AGENT` or `AGENT_TO_ANYWHERE`; the runtime references them separately (`client_to_agent_config`, `agent_to_anywhere_config`). The secured sample needs governed ingress (Model Armor) and governed egress (default-deny allowlist for GCS, Cloud Run, Gemini).

## Decision
Provision one gateway per mode in `europe-west1`, same project. Egress reaches the VPC through an agent connectivity template (network attachment + DNS peering). IAM egress policies (`roles/iap.egressor`) are the only allowlist.

## Consequences
Higher fixed cost than a single gateway; documented in the FinOps table of the sample README.
