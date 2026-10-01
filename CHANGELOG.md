# Changelog

## [2026-10-01] - Daily Log - Repository bootstrap, GEAP verification and CI foundations

- **repo**: initialise git repository, add `PLAN.md` execution plan
- **docs**: record Phase 0 verification results in `docs/VERIFICATION.md` (Agent Registry, IAP egress and semantic governance are Terraform resources in `google` 8.5.0)
- **quality**: add pre-commit suite (hygiene, Terraform fmt/validate/tflint/docs, gitleaks, ruff, conventional commits)
- **taskfile**: add root Taskfile (bootstrap, lint, KICS, Trivy, orchestration of the samples)
- **ci**: add GitHub Actions — reusable per-sample pipeline, path-filtered workflows, repo-wide pre-commit/KICS/Trivy; actions pinned by SHA
- **adr**: add ADR 001-004 (mechanism order, Agent Identity, Model Armor at gateway, dual gateway)
