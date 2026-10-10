# Changelog

## [2026-10-10] - Daily Log - geap-agent-secured-v2: client 404 traced to a zsh probe artifact, e2e 6/6

- **ci**: fix the red workflows — Google provider pinned to `8.5.0` in the three samples (the floating `~> 8.5` resolved 8.6.0 on CI and made the generated `TFDOCS.md` drift, lock files being gitignored), offline Application Default Credentials fixture for the Python tests (`tests/conftest.py`), `actions: read` on the `check-cyber` jobs uploading SARIF (private repository)
- **ci**: workflows renamed by responsibility — `ci-<sample>` → `build-<sample>` (reusable `_sample.yml` → `_build-sample.yml`, steps labelled Lint/Syntax/Tests, per-ref `concurrency`), `ci-repo` → `check-cyber` (KICS + Trivy only); the `pre-commit` job moves unchanged to the new `check-quality`; no Java/Maven (none in repo), `terraform plan` stays out of CI (no cloud credentials)
- **agents**: `AGENTS.md` is now the only instruction file (`AGENT.md` renamed, `CLAUDE.md` and `GEMINI.md` removed, GEMINI formatting rules merged); `.task/` (Task checksum cache) untracked and gitignored
- **geap-agent-secured**: destroyed and rebuilt without the `-v2` suffix (state prefix, gateways, bucket, function, service accounts, agent, sandbox name, labels, test file); function husk left by a failed delete removed with the Artifact Registry tag immutability lifted then restored; e2e fresh-engine session creation fails for ~1 min after apply (propagation), then succeeds
- **geap-agent-secured**: renamed from `geap-agent-secured-v2` (folder, CI workflow, Task namespace `secured:`, docs); deployed identifiers (state prefix, gateway/bucket/agent names, labels) intentionally keep the `-v2` suffix to avoid replacing live resources
- **geap-agent-secured**: previous version removed (cloud resources already destroyed, empty state); Taskfile includes, `test-all`/`apply-all`/`destroy-all`, CI workflow, `kics.config` and README table updated, dead links to its README fixed
- **geap-agent-secured-v2**: the client `404` (`server: ESF`) was a measurement artifact — zsh read `$ENG:streamQuery` as the `:s` modifier and dropped the method from the probe URL; the agent always answered (`task e2e` 6/6 in 43 s). Diagnostic changes made meanwhile were reverted; the engine was recreated (new id) and the ingress gateway re-adopted by the Fabric module with `terraform state rm` + `import`
- **geap-agent-secured-v2**: fix a silent missing ingress binding on engine updates — `google-beta` drops a `client_to_agent_config` whose gateway id is unknown at plan, so the id is now built from the gateway name; offline tests override the module `agent_gateway` output
- **docs**: record the investigation in `docs/VERIFICATION.md` (runtime revisions of `v1beta1` engines, gateway removal ordering, native sandbox 3/3 on the new engine); v2 README limitations and zsh probing tip

## [2026-10-09] - Daily Log - Secured agent sandbox diagnosed and pre-provisioned; geap-agent-secured-v2 on Cloud Foundation Fabric modules

- **geap-agent-secured**: fix code-execution queries timing out (e2e 5/6) — on the gateway-bound engine `CreateSandboxEnvironment` creates a working sandbox within a second but its operation ends in `UNAVAILABLE` after ~530 s, and the ADK executor waited for it in the request. A sandbox is now pre-provisioned by `task sandbox` (`scripts/provision_sandbox.py`, run by `apply` and `e2e`; creation not awaited, execution smoke test, 7-day TTL, older ones deleted), and a `before_agent_callback` hands it to the executor through `session.state["sandbox_name"]`; e2e 6/6 in 40 s
- **geap-agent-secured**: fix `task destroy` failing on an engine with child resources (`FAILED_PRECONDITION ... contains child resources: sandbox environments`, verified on a throwaway engine) — `deletion_policy = "FORCE"` deletes the sessions and the sandbox with the engine; Terraform test added
- **geap-agent-secured**: the sandbox e2e test asserts on the `code_execution_result` output instead of the answer text (`scripts/invoke.py` exposes `stream_parts`); offline tests for the lookup, the callback and the provisioning script
- **geap-agent-secured-v2**: add the secured agent rebuilt on the Cloud Foundation Fabric modules (`geap-agent-gateway` ×2, `geap-agent-runtime`, `gcs`, `cloud-function-v2`, `iam-service-account`, pinned to commit `25d8d9a`: `v59.0.0` breaks DNS peering with provider 8.5); network attachment passed through the module context, per-endpoint `iap.egressor` grants kept as raw resources, `override_module` on the gateways in `terraform test`, 60 s wait for the build account IAM; offline tests (11 tftest, 43 pytest), CI workflow, root Taskfile include, ADR 005
- **geap-agent-secured-v2**: deployed after destroying `geap-agent-secured` (`RegionalAgentGateways` quota: 2 per region); native sandbox creation completes in 5-6 s on this gateway-bound engine (3/3)
- **base**: own the CMEK grants of the Cloud Functions and Cloud Run service agents (used by both secured samples); **geap-agent-secured**: forget them with `removed` blocks (no destroy), `force_destroy` on the `agent-workspace/` managed folder
- **geap-agent-secured**: destroyed; its function deletion is refused by the tag-immutable Artifact Registry repository of `base` (package cleanup), finished by lifting immutability temporarily
- **docs**: record the sandbox investigation in `docs/VERIFICATION.md` — DNS peering / `roles/dns.peer` hypothesis refuted (grants on the Vertex AI service agents tested then removed), operations API as the only source of truth, platform trigger still open; secured README updated (design decision, FinOps, troubleshooting, `task sandbox`)

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
