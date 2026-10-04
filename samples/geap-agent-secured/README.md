# 🛡️ geap-agent-secured — governed agent on Agent Runtime

Terraform documentation: [TFDOCS.md](TFDOCS.md)

An ADK agent on **Agent Runtime** that answers a simple question, reads and writes **one path** of a bucket, triggers a **Cloud Run function** and runs code in a **sandbox**. Every flow is governed: two **Agent Gateways**, **Model Armor** on the way in and out, **Agent Identity**, an **IAM egress allowlist** and a private attachment to the Belgium VPC.

> [!WARNING]
> This sample provisions billable resources (two Agent Gateways, Agent Runtime, Model Armor). Read the FinOps section, then run `task destroy` after a demo.

## ✨ Features

- Agent Identity, CMEK; every resource in `europe-west1`, model inference in an EU region (`europe-west3` by default, `model_location`).
- Ingress gateway (`CLIENT_TO_AGENT`) with Model Armor screening prompts and answers.
- Egress gateway (`AGENT_TO_ANYWHERE`), **default deny**: IAP is the gateway authorizer (`REQUEST_AUTHZ` policy); only endpoints registered in Agent Registry and granted `roles/iap.egressor` are reachable.
- Bucket access restricted to the `agent-workspace/` managed folder.
- Backend Cloud Run function (internal ingress, dedicated service accounts, no role), reached from the egress gateway through the VPC (DNS peering on `run.app.` → PSC endpoint for Google APIs of `samples/base`).
- Sandboxed code execution (hermetic, no network) through `AgentEngineSandboxCodeExecutor`.
- Agent reaches the Belgium VPC through the egress gateway (Private Service Connect attachment).
- Optional semantic governance policy (Preview).

## 🧭 Architecture

```mermaid
graph TD
    C[Client] -->|query| GI[Agent Gateway<br/>CLIENT_TO_AGENT]
    GI -->|prompt / answer| MA[Model Armor<br/>europe-west1]
    GI --> RT[Agent Runtime<br/>Agent Identity + CMEK]
    RT -->|egress| GE[Agent Gateway<br/>AGENT_TO_ANYWHERE<br/>default deny]
    GE -->|PSC attachment| VPC[Belgium VPC]
    GE -->|iap.egressor| REG[(Agent Registry<br/>allowlist)]
    GE --> LLM[Gemini regional endpoint<br/>EU model_location]
    GE --> GCS[(Bucket<br/>agent-workspace/ only)]
    VPC --> PSC[PSC endpoint Google APIs<br/>run.app private zone]
    PSC --> FN[Cloud Run function<br/>internal only]
    RT --> SB[Code sandbox<br/>no network]
```

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Ingress gateway
    participant M as Model Armor
    participant A as Agent
    participant E as Egress gateway
    C->>G: question
    G->>M: screen prompt
    M-->>G: allow / deny
    G->>A: question
    A->>E: Gemini / GCS / function (agent identity)
    E-->>A: allowed endpoints only
    A-->>G: answer
    G->>M: screen answer
    G-->>C: answer
```

### Key Design Decisions

| Decision | Choice | Why |
|---|---|---|
| Gateways | Two, one per governed access path | `CLIENT_TO_AGENT` and `AGENT_TO_ANYWHERE` are distinct modes ([ADR 004](../../docs/adr/004-dual-agent-gateway.md)) |
| Model Armor | Enforced at the ingress gateway (authz extension + `CONTENT_AUTHZ` policy), fail closed | No guardrail code in the agent ([ADR 003](../../docs/adr/003-model-armor-at-gateway.md)) |
| Bucket scope | Managed folder + `objectUser` | IAM conditions do not restrict object listing; agent identities cannot hold `legacyBucket*` roles |
| Function trigger | HTTPS call with an ID token through the egress gateway, then the VPC: the connectivity template peers `run.app.` with the private zone of `samples/base` (PSC endpoint for Google APIs) | An `ALLOW_INTERNAL_ONLY` service answers `404 Page not found` to traffic that does not enter from the VPC; the gateway otherwise reaches `*.run.app` over the Google network |
| Connectivity template | ID suffixed by a hash of its network settings, `create_before_destroy` | The API rejects any update of a referenced template (`cannot update agent connectivity template that is referenced by an agent gateway`): a change creates a new template, switches the gateway in place, then deletes the old one |
| Model location | `model_location` (EU regions only, default `europe-west3`), passed to the model client only | `gemini-3.x` is not served in `europe-west1`; the `eu` multi-region has no mTLS host (Agent Identity uses mTLS); sessions and sandbox stay on the engine region (`ENGINE_LOCATION`) |
| Sandbox | `AgentEngineSandboxCodeExecutor` on the agent's own engine | No Terraform cycle; disabled with a warning if the engine cannot be resolved |
| VPC attachment | Through the egress gateway connectivity template | The API forbids a direct PSC interface on an engine that uses an Agent Gateway |
| Egress policy | `google_agent_registry_service` + `google_iap_agent_registry_endpoint_iam_member`, evaluated by an IAP authz extension (`REQUEST_AUTHZ`, IAM Allow policy `V1`, fail closed) on the egress gateway | Everything is Terraform ([ADR 001](../../docs/adr/001-terraform-first-mechanism-matrix.md)); without the IAP policy the gateway denies every request (`default_denied`) |
| Semantic governance | Opt-in flag, Preview | Billed per LLM evaluation; not default |

## 🔒 Security Design

| Control | Implementation |
|---|---|
| Identity | `AGENT_IDENTITY`, no service account, no key |
| Least privilege | Project roles: `aiplatform.user`, `logging.logWriter`. Bucket: `objectUser` on the managed folder only. Function: `run.invoker` on that function only |
| Prompt / answer screening | Model Armor (prompt injection, jailbreak, malicious URL, RAI, SDP) at the ingress gateway |
| Egress | Default deny; IAP authorizes each request against the explicit allowlist in `registry.tf` (exact hostnames, standard and mTLS) |
| Data at rest | One CMEK key (bucket, function, agent) |
| Network | VPC access through the egress gateway PSC attachment (/28 subnet); function `ALLOW_INTERNAL_ONLY`, reached through the PSC endpoint for Google APIs; no NAT, no public IP |
| Sovereignty | `region` validated to `europe-west1` for every resource; `model_location` validated to EU member-state regions (Terraform and `config.py`); regional endpoints only, never `global` |
| Defence in depth | Tool-level path scoping on top of IAM; payload and file size limits |

> [!IMPORTANT]
> Preview surfaces (Agent Gateway, Agent Registry, semantic governance) and a few runtime behaviours could only be verified at deployment time. See "To validate at first apply" below.

## 💰 FinOps

| Item | Estimate | Cheaper option |
|---|---|---|
| Agent Gateways ×2 | Not published in the sources used for this sample — check the pricing page before applying | One gateway only drops either governed ingress or governed egress |
| Agent Runtime | vCPU/GiB-hours while an instance is up | `min_instances = 0` |
| Model Armor | Free monthly allotment, then per volume | Keep templates as is |
| Cloud Run function, GCS, KMS | Cents for a demo | — |
| PSC endpoint for Google APIs + private DNS zone | Owned by `samples/base`: hourly charge per PSC endpoint + data processed, monthly fee per zone — check the pricing pages | Needed only for the internal-only function |
| Semantic governance | LLM call per evaluation | Off by default |

> [!TIP]
> Destroy the stack after each session: the gateways are the fixed cost of this sample.

## 📋 Prerequisites

`task setup` at the root, `gcloud auth application-default login`, `task bootstrap`, `task base:apply` (the CMEK key, the VPC and the Docker repository come from `samples/base`).

## 🚀 Deployment

```bash
task setup      # venv + pinned dependencies
task test       # offline Python + Terraform tests (no credentials)
task plan       # packages the agent, then terraform plan
task apply      # billable, no confirmation prompt
task invoke -- "Write 'hello' in agent-workspace/hello.txt then read it back"
task e2e        # optional end-to-end checks against the deployed agent (billable)
```

### To validate at first apply

| Point | What to check |
|---|---|
| CMEK on the agent engine | The Agent Runtime service agent can use the key (granted in `samples/base`); if the apply fails on the key, re-run once the service agent exists |
| Egress registry model | Each registered service of type endpoint creates its registry endpoint synchronously (confirmed at first apply): its name is the service `registry_resource` attribute, used directly as the `roles/iap.egressor` target |
| Function call from the agent | Confirmed on 2026-10-04 through the VPC path (DNS peering on `run.app.` → PSC endpoint for Google APIs): Cloud Run logs `POST 200`. Without it, Cloud Run answers `404 Page not found` (traffic from outside the VPC) |
| Sandbox | **Open (2026-10-04)**: the executor creates one sandbox per session. On this gateway-bound engine, creation took 3 to 9 min without DNS peering and failed with `UNAVAILABLE` (twice) with it, against 3 to 5 s on the `geap-agent-simple` engine (no gateway). A code-execution query therefore exceeds the 180 s client timeout, and while the executor polls the creation it blocks the instance. See `docs/VERIFICATION.md` |
| VPC attachment | The API rejects `psc_interface_config` together with `agent_gateway_config` (confirmed at first apply): the VPC is reached through the egress gateway attachment only |
| Model availability | Confirmed on 2026-10-04: `gemini-3.5-flash` is served by `europe-west3` (and the `eu` multi-region, excluded: no mTLS host), not by `europe-west1`, which serves `gemini-2.5-*` only |

### Troubleshooting egress (Agent Gateway)

The egress gateway denies everything that is not registered **and** granted `roles/iap.egressor` to the agent identity; a denial shows up as `403 Egress request is not authorized` or as connection errors in the agent logs. The IAP decision of each request is in the gateway log (`jsonPayload.authzPolicyInfo.result`, with the real URL in `httpRequest.requestUrl`).

```bash
# Agent runtime logs (build, start-up, requests)
gcloud logging read 'resource.type="aiplatform.googleapis.com/ReasoningEngine" AND severity>=WARNING' --project="$GCP_PROJECT_ID" --freshness=1h

# Gateway decisions (stored in the europe-west1 log bucket of samples/base)
gcloud logging read 'logName:"gateway_requests"' --project="$GCP_PROJECT_ID" --bucket=logs-gcp-samples-ew1 --location=europe-west1 --view=_AllLogs --freshness=1h

# IAP egress authorization (Data Access audit logs, enabled by this sample; no entry observed on 2026-10-04, the gateway log above carries the decision)
gcloud logging read 'protoPayload.serviceName="iap.googleapis.com" AND protoPayload.authorizationInfo.permission="iap.resources.egressViaIAP"' --project="$GCP_PROJECT_ID" --freshness=1h
```

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to convert project number to project ID` at start-up | Resource Manager hostname not allowed, or `roles/browser` missing | Both are in this sample; the first start-up of a new engine can still log it once, because the grants can only exist after the engine (its principal) does |
| Every gateway entry is `CONNECT 240.0.0.2:443`, rule `default_denied`, no `authzPolicyInfo` | No IAP `REQUEST_AUTHZ` policy on the egress gateway: nothing evaluates the `iap.egressor` grants | `google_network_security_authz_policy.iap_egress` (`policies.tf`) |
| `Cannot connect to host <host>:443` / `authzPolicyInfo.result` denied | Hostname not in `registry.tf` (exact match, standard **and** `.mtls.` variants), or no `iap.egressor` grant | Register the host and re-apply |
| `404 Publisher model ... was not found` | Model not served by the regional endpoint of `model_location` | Pick an EU region that serves it (`europe-west3` for `gemini-3.5-flash`) or a `gemini-2.5-*` model in `europe-west1` |
| `403 Egress request is not authorized` right after adding a host | New `iap.egressor` grant not propagated yet | Retry after ~2 min |
| Function call returns `404 Page not found` | The gateway reaches `*.run.app` outside the VPC, refused by the `ALLOW_INTERNAL_ONLY` ingress | DNS peering on `run.app.` (`gateway.tf`) + PSC endpoint and private zone (`samples/base`) |
| `cannot update agent connectivity template that is referenced by an agent gateway` | Templates are immutable while referenced | Handled by the hashed template ID + `create_before_destroy` (`gateway.tf`) |
| `unregisteredResource` in the IAP audit log | Destination not registered in Agent Registry | Add it to `local.egress_endpoints` |

### Semantic governance wiring (optional)

`enable_semantic_governance = true` creates the policy engine and an agent-scope policy. Attaching the engine to the egress gateway needs the engine DNS hostname, which the provider does not expose: create the authz extension and the authz policy as described in the [semantic governance guide](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/policies/configure-semantic-governance) (policy on `:generateContent` and `:streamGenerateContent` only, start in `DRY_RUN`). It cannot be combined with Model Armor on the ingress gateway, hence the egress attachment.

## 🧰 Task Commands

| Command | Description |
|---|---|
| `task setup` / `task lock` | Create `.venv` / re-compile pinned requirements |
| `task package` | Build the deterministic agent archive |
| `task plan` / `task apply` / `task destroy` | Terraform lifecycle (`destroy` asks for confirmation) |
| `task invoke -- "<question>"` | Query the deployed agent |
| `task e2e` | Billable end-to-end checks (excluded from CI) |
| `task test` | Offline Python and Terraform tests |
| `task lint` | ruff and pyright |

## 🗂️ Project Structure

```text
samples/geap-agent-secured/
├── app/                  # archive root: agent.py, tools.py, config.py, logger.py, requirements.txt
├── function_src/         # Cloud Run function (main.py, requirements.txt)
├── scripts/              # package.py, invoke.py
├── tests/                # pytest, secured.tftest.hcl, fixtures/, e2e/ (excluded from CI)
├── main.tf  backend.tf  variables.tf  outputs.tf
├── storage.tf            # bucket + agent-workspace/ managed folder
├── function.tf           # Cloud Run function + dedicated service accounts
├── network.tf            # PSC network attachments
├── model_armor.tf        # templates + authz extension + CONTENT_AUTHZ policy
├── gateway.tf            # ingress and egress Agent Gateways
├── agent.tf  iam.tf      # Agent Runtime engine and least-privilege grants
├── registry.tf  policies.tf  # egress allowlist, IAP authz policy + iap.egressor grants, semantic governance
└── Taskfile.yml
```
