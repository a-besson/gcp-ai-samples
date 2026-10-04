# Changelog

## [2026-10-04] - Daily Log - Secured agent egress: plan-time registry lookup, IAP authorizer, EU inference and private path to the internal function

- **geap-agent-secured**: fix `secured:plan` failing with `did not find an Endpoint ... matching filter displayName=...` — the IAP grants now read the endpoint from `google_agent_registry_service.registry_resource` instead of a registry lookup that ran at plan time (untriggered `time_sleep`); the data source and the 60 s wait are removed
- **geap-agent-secured**: fix every egress request being denied (`default_denied`) — attach an IAP authz extension (`REQUEST_AUTHZ`, IAM Allow policy `V1`, fail closed) to the egress gateway so the `roles/iap.egressor` grants are evaluated; offline test added
- **geap-agent-secured / geap-agent-simple**: fix model calls returning 404 (`gemini-3.5-flash` is not served in `europe-west1`) — inference now runs in an EU region (`model_location`, EU member-state regions only, default `europe-west3`) passed to the model client only, while resources, sessions and sandbox stay in `europe-west1`; model hosts added to the secured egress allowlist
- **geap-agent-secured**: fix `task invoke` truncating the question to its first word (double quoting of `CLI_ARGS`)
- **base**: add a Private Service Connect endpoint for Google APIs (`all-apis`) and a private `run.app.` zone pointing to it, exported as `run_app_private_dns_name`
- **geap-agent-secured**: fix the internal-only function answering `404 Page not found` to the agent — the egress connectivity template peers `run.app.` with the base private zone (`roles/dns.peer` for the Agent Gateway service agent); the template ID carries a hash of its network settings with `create_before_destroy`, since a template referenced by a gateway cannot be updated
- **docs**: record the 2026-10-04 re-apply results in `docs/VERIFICATION.md`; READMEs updated (IAP decision in the gateway log, EU inference, private path to the function, template naming)

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
- **base**: budget resolves its billing account from the variable, else the project data source, else is disabled; enable `cloudbilling`/`cloudasset` APIs
- **base**: fix CMEK grants — wait 30 s for new service agents (IAM "does not exist" race), grant Agent Platform agent, add `extra_cmek_service_agents`; Cloud Run/Functions agents moved to `geap-agent-secured`
- **geap-agent-simple / geap-agent-secured**: fix engine start-up ("Class LlmAgent is missing all methods query...") — entrypoint is now an `AdkApp` wrapper (`adk_app`) instead of the bare `LlmAgent`
- **taskfile**: pass `-auto-approve` to every `terraform apply` / `destroy` ; no confirmation prompt on `apply` (kept on `destroy`)
- **base**: enable the full Agent Platform API set (Agent Identity, App Hub, App Topology, Cloud API Registry, Dataform, Notebooks, Observability, App Lifecycle Manager, Security Command Center, Text-to-Speech)
- **base / geap-agent-secured**: fix function build repository — `artifact_registry_repository` output is now the full path (`.id`), and the function builds the path from the repository ID
- **geap-agent-secured**: remove `psc_interface_config` from the engine (rejected by the API together with `agent_gateway_config`); the VPC is reached through the egress gateway attachment; drop the unused agent network attachment
- **geap-agent-secured**: fix egress denials seen in agent runtime logs — allow Resource Manager/Cloud Trace/Secret Manager/aiplatform `rep` hosts, register endpoints with the `JSONRPC` binding, grant the runtime roles (browser, agentregistry.viewer, metric/trace writers), enable IAP Data Access audit logs, add egress troubleshooting guide
- **scan**: exclude `.terraform`/`.venv` from Trivy and KICS; pin KICS image to `v2.1.20` (v2.2.0 not published on Docker Hub)
- **adr**: add ADR 001-004 (mechanism order, Agent Identity, Model Armor at gateway, dual gateway)
