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

## État après la construction des phases 2 à 6 (2026-10-01)

Tout le code est écrit et validé **hors ligne** (providers mockés) ; aucun `apply` n'a été lancé. Les points V-runtime restent donc ouverts et sont listés dans le README du sample sécurisé (« To validate at first apply »).

| ID | Statut | Détail |
|---|---|---|
| V3 | ouvert | Principal construit avec `principal://<effective_identity>` (cf. doc). À confirmer : accepté par les bindings IAM. |
| V7 | ouvert | Binding `roles/storage.objectUser` sur le managed folder pour l'Agent Identity. |
| V8 | ouvert | ID token Agent Identity pour la function interne ; variable `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=false` reprise de la doc gateway. |
| V9 | ouvert | Le sandbox est rattaché au moteur de l'agent via `GOOGLE_CLOUD_AGENT_ENGINE_ID` (ou `AGENT_ENGINE_RESOURCE_NAME`) ; sans moteur résolu, l'exécuteur est désactivé avec un avertissement. |
| V12 | ouvert | Modèle par défaut `gemini-2.5-flash` (variable `model`) : disponibilité sur l'endpoint régional `europe-west1` non vérifiée (APIs non activées avant `base:apply`). |

Hypothèses de modélisation à valider au premier apply (voir aussi le README du sample sécurisé) :
- Agent Registry : un `google_agent_registry_service` avec `endpoint_spec` apparaît comme *endpoint* du registre, retrouvé par `displayName`.
- PSC-I et `agent_gateway_config` sur le même moteur.
- Service agents : `gcp-sa-aiplatform-re` existe quand l'API Agent Platform est activée (lié au CMEK du moteur).
- `google_project_service_identity` pour `cloudfunctions.googleapis.com` et `run.googleapis.com`.

## Résultats du premier apply (2026-10-01)

| Sujet | Résultat |
|---|---|
| PSC-I + `agent_gateway_config` | **Incompatibles** : `spec.deployment_spec.psc_interface_config and spec.deployment_spec.agent_gateway_config cannot be both set` (HTTP 400). Le rattachement au VPC passe par le `network_attachment` du modèle de connectivité de la gateway de sortie. |
| Point d'entrée de l'agent | Doit être un objet exposant `query`/`stream_query`/`async_stream_query` : `AdkApp(agent=root_agent)`, pas un `LlmAgent` brut. |
| Chemin du dépôt Artifact Registry | Cloud Functions exige `projects/<p>/locations/<l>/repositories/<r>`. |
| Agents de service | Course de propagation IAM (« does not exist ») : attente de 30 s avant l'octroi sur la clé KMS. |

## Analyse des logs de l'agent sécurisé (2026-10-01)

| Constat | Détail |
|---|---|
| Toute requête de l'agent est refusée par la gateway de sortie | 217 entrées `gateway_requests` : `CONNECT 240.0.0.2:443`, HTTP 403, règle `default_denied` (le nom d'hôte réel n'apparaît pas dans ce journal). |
| Démarrage | `Failed to convert project number to project ID` : appels gRPC vers Resource Manager (non enregistré) → 60 s de timeout puis démarrage avec le numéro de projet. |
| Requêtes | La création de session vers `europe-west1-aiplatform.mtls.googleapis.com` échoue (`ConnectionResetError`) alors que l'hôte était enregistré et accordé. |
| Corrections apportées | Hôtes ajoutés (`cloudresourcemanager` ± mTLS, `cloudtrace`, `secretmanager`, `aiplatform.<région>.rep`), binding `JSONRPC` (celui de la doc) au lieu de `HTTP_JSON`, rôles `browser`, `agentregistry.viewer`, `monitoring.metricWriter`, `cloudtrace.agent` pour l'identité de l'agent, logs d'audit IAP Data Access activés. |
| Non confirmé | Que `JSONRPC` soit bien la cause du refus de l'hôte déjà enregistré : à vérifier avec le journal d'audit IAP après réapplication. |
| Trust domain | L'identité réelle est `agents.global.org-<ORG_ID>...` : le projet est donc rattaché à une organisation (contrairement à ce qui avait été indiqué). Le principal est dérivé de `effective_identity`, donc sans impact. |

## Réapplication du sample sécurisé (2026-10-04)

| Sujet | Résultat |
|---|---|
| Échec de `secured:plan` | `did not find an Endpoint ... matching filter displayName=...` pour les 7 hôtes ajoutés le 2026-10-01. Cause : `time_sleep.registry_ingestion` sans `triggers`, déjà en state, donc sans changement planifié → `data.google_agent_registry_endpoint` lu au plan, avant la création des services. |
| Modèle du registre | Hypothèse « endpoint retrouvé par `displayName` après ingestion asynchrone » **infirmée** : l'endpoint est créé avec le service (~100 ms) et son nom est exposé par `google_agent_registry_service.registry_resource`. La data source et l'attente de 60 s sont supprimées. |
| Refus de toute la sortie | Les 474 entrées `gateway_requests` (`CONNECT 240.0.0.2:443`, `default_denied`, `agentGatewayInfo` vide) venaient de l'absence d'autorisateur : aucune authz policy sur la gateway de sortie, donc les grants `roles/iap.egressor` n'étaient jamais évalués. `JSONRPC` n'était **pas** la cause. Correctif : authz extension `iap.googleapis.com` (`iapPolicyVersion: V1`, fail closed) + authz policy `REQUEST_AUTHZ` / `CUSTOM` sur la gateway de sortie. Les journaux de la gateway portent ensuite l'URL réelle et `authzPolicyInfo.result = ALLOWED`. |
| V12 (modèle) | **Résolu** : l'endpoint régional `europe-west1` sert `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.5-pro` ; `gemini-3-flash`, `gemini-3-flash-preview`, `gemini-3.5-flash`, `gemini-3.5-flash-lite` y répondent `404 Publisher model ... was not found`. En UE, `gemini-3.5-flash` est servi par `europe-west3` et par le multi-région `eu` (404 sur `europe-west4`, `-west8`, `-west9`, `-north1`, `-southwest1`, `-central2`) ; `gemini-3-flash` par aucune. Décision : inférence autorisée sur les régions UE (`model_location`, défaut `europe-west3`), ressources toujours en `europe-west1`. `eu` est exclu : sous Agent Identity, `google-genai` passe en mTLS et réécrit l'hôte en `aiplatform.eu.rep.mtls.googleapis.com`, qui n'existe pas en DNS. |
| Propagation IAM | Les nouveaux grants `roles/iap.egressor` (hôtes `europe-west3`) ont renvoyé `403 Egress request is not authorized` pendant ~2 min après leur création, puis `ALLOWED`. |
| Journaux d'audit IAP | Aucune entrée Data Access `iap.googleapis.com` observée ~20 min après l'activation, alors que les décisions IAP apparaissent dans `gateway_requests` (`authzPolicyInfo`). |
| e2e | 1er passage (modèle `europe-west1`, sans chemin privé) : 5/6, function KO. Passage final (modèle `europe-west3`, chemin privé vers la function) : 5/6 — question simple, écriture dans `agent-workspace/`, refus hors workspace, function, blocage Model Armor OK ; sandbox KO (ligne Sandbox). |
| V8 (function interne) | **Résolu** : sans chemin privé, `404 Page not found` (même réponse depuis l'extérieur du VPC), aucune requête côté Cloud Run : la gateway atteint `*.run.app` par le réseau Google (`vpc_egress` par défaut = plages privées uniquement). Correctif (codelab « Agent Gateway egress from Agent Runtime to VPC network ») : endpoint PSC pour Google APIs (`all-apis`, `240.0.0.10`) et zone privée `run.app.` dans `samples/base`, `dns_peering_config` sur le modèle de connectivité, `roles/dns.peer` pour le service agent `gcp-sa-agentgateway`. Cloud Run journalise ensuite `POST 200`, réponse `accepted`. |
| Sandbox (exécution de code) | **Ouvert** : l'exécuteur ADK crée un sandbox par session et attend la fin de l'opération en bloquant (polling toutes les 0,1 s). Sur l'engine secured (lié à une gateway), créations : 2 min 47 s (16:11, avant tout changement réseau), 8 min 43 s et 25 s sans DNS peering, `UNAVAILABLE` après 5 à 9 min avec DNS peering (2 sur 2). Sur l'engine du sample simple (sans gateway) : 3 à 5 s. Une requête avec du code dépasse donc le timeout client de 180 s ; le test e2e n'était passé à 16:14 qu'avec 5 s de marge. Pistes non testées : `roles/dns.peer` pour les service agents Vertex AI, sandbox pré-créé (`sandbox_resource_name`). |
| Modèle de connectivité | L'API refuse toute mise à jour d'un modèle référencé : `Precondition failed: cannot update agent connectivity template that is referenced by an agent gateway` (non détecté par `terraform plan`, qui annonçait un update in-place). Contournement : ID suffixé par un hash des réglages réseau + `create_before_destroy` ; la gateway bascule in-place vers le nouveau modèle (pas de remplacement de la gateway ni de l'engine). |
