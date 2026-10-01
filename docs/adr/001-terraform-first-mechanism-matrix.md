# 001 — Terraform first, then SDK, then CLI
**Date:** 2026-10-01 | **Status:** accepted

## Context
The goal is to automate every GEAP component. Several of them are recent (Agent Gateway, Agent Registry, semantic governance) and may lack Terraform support.

## Decision
Mechanism order: Terraform resource → Python SDK (ADK) → CLI (`gcloud`, `agents-cli`). Phase 0 checked the `google` provider 8.5.0 schema: Runtime, Agent Identity, Gateway, Model Armor, authz policies, Agent Registry, IAP egress bindings and semantic governance are all Terraform resources. Only the sandbox (created by the ADK executor at runtime) is not.
The agent is deployed by Terraform (`source_code_spec` + `python_spec`); `agents-cli` is limited to scaffold, local run and eval because its generated `Makefile` and `deployment/` conflict with the repo conventions.

## Consequences
Terraform is the single owner of the state. See `docs/VERIFICATION.md` for the evidence.
