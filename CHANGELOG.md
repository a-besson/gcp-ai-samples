# Changelog

## [2026-10-01] - Daily Log - Repository bootstrap, GEAP verification and CI foundations

- **repo**: initialise git repository, add `PLAN.md` execution plan
- **docs**: record Phase 0 verification results in `docs/VERIFICATION.md` (Agent Registry, IAP egress and semantic governance are Terraform resources in `google` 8.5.0)
- **quality**: add pre-commit suite (hygiene, Terraform fmt/validate/tflint/docs, gitleaks, ruff, conventional commits)
- **taskfile**: add root Taskfile (bootstrap, lint, KICS, Trivy, orchestration of the samples)
- **ci**: add GitHub Actions — reusable per-sample pipeline, path-filtered workflows, repo-wide pre-commit/KICS/Trivy; actions pinned by SHA
- **setup**: add `Brewfile`, `task setup` / `task doctor`; Python 3.14 locally and in CI (Agent Runtime stays on 3.13, its max supported version)
- **base**: add shared stack — CMEK key, Belgium VPC (no NAT), regional log bucket, Artifact Registry, optional budget; offline `terraform test` suite
- **base**: grant the shared CMEK key to the Agent Platform, Agent Runtime, Cloud Run and Cloud Functions service agents
- **geap-agent-simple**: add ADK agent deployed from source on Agent Runtime (Agent Identity, CMEK, europe-west1), deterministic packaging, offline pytest and `terraform test` suites
- **geap-agent-secured**: add governed agent — ingress/egress Agent Gateways, Model Armor via authz extension (fail closed), PSC attachment to the Belgium VPC, managed-folder scoped bucket access, internal-only Cloud Run function, sandboxed code execution, Agent Registry egress allowlist with `roles/iap.egressor`, optional semantic governance; offline pytest (25) and `terraform test` (10) suites, billable e2e suite excluded from CI
- **scan**: exclude `.terraform`/`.venv` from Trivy and KICS; pin KICS image to `v2.1.20` (v2.2.0 not published on Docker Hub)
- **adr**: add ADR 001-004 (mechanism order, Agent Identity, Model Armor at gateway, dual gateway)
