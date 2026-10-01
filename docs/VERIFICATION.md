# VERIFICATION — résultats Phase 0

> Date : 2026-10-01. Source de vérité des points 🔎 de `PLAN.md`.
> Environnement : Terraform 1.16.4, providers `google` **et** `google-beta` v8.5.0 (schémas lus via `terraform providers schema -json`), gcloud 585.0.0 (composants `alpha`/`beta` **non installés**).

## Écart par rapport au plan initial

Le provider GA `google` v8.5.0 expose déjà des ressources Terraform que le plan supposait absentes :
`google_agent_registry_service`, `google_agent_registry_binding`, `google_iap_agent_registry_{endpoint,agent,mcp_server}_iam_{member,binding,policy}`, `google_vertex_ai_semantic_governance_policy_engine`, `google_vertex_ai_semantic_governance_policy`.
→ La Phase 6 passe **100 % Terraform** (plus de scripts `gcloud`). Aucun besoin des composants gcloud alpha/beta.

## V-static

| ID | Résultat | Source | Impact sur le plan |
|---|---|---|---|
| V1 | Versions : `google-adk` 2.10.0, `google-cloud-aiplatform` 2.3.0, `google-genai` 2.26.0, `google-agents-cli` 1.8.0, `tenacity` 9.1.4, `pydantic` 2.13.5, `google-cloud-storage` 3.15.1, providers `google`/`google-beta` 8.5.0. Le paquet `agentplatform` n'existe pas sur PyPI sous ce nom (SDK à confirmer plus tard, non bloquant : on déploie par Terraform). Python `python_spec.version` supporte 3.9–3.13. | `pip index versions`, `terraform init` | Épingler ces versions en Phase 3. Python local = 3.14.8 : un 3.13 est requis pour coller au runtime (voir « Outils manquants »). |
| V2 | Dans le provider **GA** : `spec.identity_type`, `spec.effective_identity`, `spec.deployment_spec.agent_gateway_config`, `deployment_spec.psc_interface_config`, `encryption_spec`, `source_code_spec`/`python_spec`, `deployment_spec.{min,max}_instances`. Compatibilité PSC-I + gateway sur un même engine : **non démontrable par le schéma** (les deux blocs coexistent syntaxiquement). | `terraform providers schema -json` | Provider `google` suffit pour l'agent ; `google-beta` non requis a priori. Compatibilité à confirmer au premier apply du secured (risque conservé). |
| V4 | `google_network_services_agent_gateway` : `location` requis, `google_managed.governed_access_path` ∈ {`AGENT_TO_ANYWHERE`, `CLIENT_TO_AGENT`}. Doc « supported locations » : Agent Gateway supporté en `europe-west1`. | schema + doc agent-locations (recherche) | D1/D4 confirmés. |
| V5 | **Confirmé par la doc** : Model Armor s'applique en `CLIENT_TO_AGENT` (inspection des prompts entrants) et en `AGENT_TO_ANYWHERE`. **Contrainte** : en ingress, la semantic governance **ne peut pas être combinée** avec Model Armor ; les IAM policies ne s'appliquent **pas** à l'ingress. Extension : `service = "modelarmor.<region>.rep.googleapis.com"` pour `CONTENT_AUTHZ`. | doc Agent Gateway overview ; doc provider `network_services_authz_extension` | D5 retenu. Semantic governance posée uniquement sur `agw-egress`. |
| V6 | Ressources TF disponibles (voir « Écart »). Champs : `google_agent_registry_service` (`service_id*`, `location*`, `[interfaces]`, `[agent_spec]`, `[endpoint_spec]`, `[mcp_server_spec]`) ; `google_iap_agent_registry_endpoint_iam_member` (`endpoint_id*`, `location*`, `member*`, `role*`). | schema | Phase 6 = Terraform. |
| V10 | `google_vertex_ai_semantic_governance_policy_engine` (`region`, `[gateway_configs]`) et `google_vertex_ai_semantic_governance_policy` (`agent*`, `natural_language_constraint*`, `semantic_governance_policy_id*`, `region`, `[mcp_tools]`). Feature en **Preview**, supportée en `europe-west1`. Coût non publié dans ce qui a été lu. | schema + doc configure-semantic-governance | Flag `enable_semantic_governance` conservé (défaut `false`). |
| V11 | `agents-cli` 1.8.0 (`uvx google-agents-cli setup`). Commandes documentées : `scaffold enhance --deployment-target agent_runtime`, `deploy`, `infra single-project`. `scaffold` génère `app/agent.py`, `app/agent_engine_app.py`, `.cloudbuild/`, `deployment/` et un **`Makefile`** (contraire à la règle « zéro Makefile »). Non installé localement (uv absent). | doc adk.dev | `agents-cli` limité au scaffold/run/eval ; ne jamais committer le `Makefile` ni `deployment/` générés. |
| V13 | Endpoints à autoriser en egress (mode exact, pas de wildcard) : `agentregistry`, `logging`, `telemetry`, `monitoring`, `secretmanager`, `iamcredentials`, `aiplatform` (+ variantes `*.mtls.googleapis.com` et `europe-west1-aiplatform[.mtls].googleapis.com`) ; ajouter `storage.googleapis.com` et l'URL de la function. Gateway en politique **default deny**. | doc « Route Agent Runtime traffic through Agent Gateway » | Utiliser `google_agent_registry_service` (endpoint_spec) + `google_iap_agent_registry_endpoint_iam_member` (`roles/iap.egressor`). |

## V-runtime (différés)

| ID | Ce que dit la doc | Différé à |
|---|---|---|
| V3 | Principal : `principal://<effective_identity>` ; trust domain `agents.global.org-<ORG_ID>.system.id.goog` (avec org) ou `agents.global.proj-<PROJECT_NUMBER>.system.id.goog` (sans). | Phase 5 |
| V7 | Non documenté : IAM de managed folder avec un principal Agent Identity. | Phase 5 |
| V8 | Non documenté : ID token Agent Identity → Cloud Run interne ; variable `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=False` utilisée dans les exemples de la doc gateway. | Phase 5 |
| V9 | Non documenté : variable d'environnement exposant l'ID de l'engine ; `AgentEngineSandboxCodeExecutor` accepte `agent_engine_resource_name` ou `sandbox_resource_name`. | Phase 5 |
| V12 | Doc locations lue : disponibilité du modèle sur endpoint régional `europe-west1` **non trouvée**. Model Armor : `europe-west1` supporté (PI/jailbreak, malicious URL, RAI, SDP, multilingue ; pas d'image). | Phase 3 |

## Outils manquants sur la machine

| Outil | Statut | Besoin |
|---|---|---|
| `uv` | absent | venvs, `agents-cli` (`uvx`), compilation des requirements |
| `python3.13` | absent (3.14.8 présent) | alignement avec `python_spec.version = "3.13"` et tests |
| `ruff` | absent | lint/format Python (peut venir du venv ou de pre-commit) |
| `kics` | absent | scan IaC (prévu via image `podman`, podman 6.1.3 présent) |
| `actionlint` | absent | validation des workflows (optionnel) |

Présents : terraform 1.16.4, tflint 0.64.0, terraform-docs 0.24.0, pre-commit 4.6.2, task 3.53.1, gcloud 585.0.0, trivy 0.74.0, gitleaks 8.30.1, gh 2.102.0, podman 6.1.3.
