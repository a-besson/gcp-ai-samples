# ☁️ GCP Gemini Enterprise Agent Platform Samples

Industrial-grade samples for the **Gemini Enterprise Agent Platform (GEAP)**: Agent Runtime, Agent Identity, Agent Gateway, Agent Registry, Agent Policy and Agent Sandbox, built with the **ADK** and fully automated with **Terraform**, in the **Belgium region (`europe-west1`)**.

> [!IMPORTANT]
> Every sample provisions billable resources. Review the FinOps section of each sample README and run `task destroy-all` after a demo. No secret or project ID is ever committed: configuration lives in a gitignored `.env`.

## 🚀 Getting Started

Prerequisites: `terraform`, `tflint`, `terraform-docs`, `pre-commit`, `task`, `gcloud`, `trivy`, `gitleaks`, `podman`, `uv`, Python 3.14 (all installed by `task setup`).

```bash
cp .env.example .env      # fill in the placeholders
pre-commit install        # installs pre-commit and commit-msg hooks
task setup                # installs tools (Brewfile), hooks, TFLint plugins
task bootstrap            # creates the Terraform state bucket (europe-west1)
task --list
```

## 📦 Samples

| Name | Description | README |
|---|---|---|
| `base` | Shared foundations: single KMS key, Belgium VPC, logging | [samples/base](samples/base/README.md) |
| `geap-agent-simple` | ADK agent on Agent Runtime answering a question through an LLM | [samples/geap-agent-simple](samples/geap-agent-simple/README.md) |
| `geap-agent-secured` | Agent behind Agent Gateways with Model Armor, sandboxed code execution, scoped bucket access and Cloud Run function | [samples/geap-agent-secured](samples/geap-agent-secured/README.md) |

## 🧰 Task Commands

| Command | Description |
|---|---|
| `task setup` / `task doctor` | Install workstation dependencies / check them |
| `task bootstrap` | Create the Terraform state bucket (idempotent) |
| `task lint` | Run all pre-commit hooks |
| `task scan` | KICS + Trivy (HIGH/CRITICAL fail) |
| `task audit-location` | Read-only: list resources outside `europe-west1` / `global` |
| `task test-all` | Offline tests of every sample |
| `task apply-all` / `task destroy-all` | Provision / delete everything (billable) |

## 🔒 Security & sovereignty

- Regional resources only in `europe-west1`; one CMEK key shared by all samples.
- Agent Identity (no service-account keys), least-privilege IAM bound to the agent principal.
- Private networking: no public IP, no NAT, Private Google Access.
- CI limited to lint, tests, `terraform validate` and KICS/Trivy scans; GitHub Actions pinned by SHA.

## 🗂️ Project tree

```text
.
├── .github/workflows/   # per-sample CI (path-filtered) + repo-wide gates
├── docs/                # VERIFICATION.md (Phase 0 evidence), adr/
├── samples/
│   ├── base/
│   ├── geap-agent-simple/
│   └── geap-agent-secured/
├── PLAN.md              # execution plan
├── Taskfile.yml
└── .pre-commit-config.yaml
```
