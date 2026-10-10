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
| Sandbox (exécution de code) | **Contourné le 2026-10-09** (section suivante). Constat du jour, corrigé le 2026-10-09 : l'exécuteur ADK crée un sandbox par session et attend la fin de l'opération en bloquant (polling toutes les 0,1 s). Seule la création de 16:11 (avant tout changement réseau) a abouti, en 2 min 49 s ; les cinq suivantes, avec **et** sans DNS peering, ont fini en `UNAVAILABLE` après 523 à 526 s. L'entrée d'audit `operation.last` de trois d'entre elles n'avait pas de `status`, ce qui les avait fait passer pour des succès. Sur l'engine du sample simple (sans gateway) : 3 s. Une requête avec du code dépasse donc le timeout client de 180 s. |
| Modèle de connectivité | L'API refuse toute mise à jour d'un modèle référencé : `Precondition failed: cannot update agent connectivity template that is referenced by an agent gateway` (non détecté par `terraform plan`, qui annonçait un update in-place). Contournement : ID suffixé par un hash des réglages réseau + `create_before_destroy` ; la gateway bascule in-place vers le nouveau modèle (pas de remplacement de la gateway ni de l'engine). |

## Exécution de code en sandbox (2026-10-09)

| Sujet | Résultat |
|---|---|
| Source de vérité | Ni l'entrée d'audit `operation.last` (parfois sans `status`) ni le champ `state` du sandbox (`STATE_RUNNING` même après un échec) : seule l'API des opérations (`GET .../operations/<ID>`, champ `error`) donne l'issue réelle d'une création. |
| Reproduction | Engine secured, peering actif : 2 créations sur 2 en `UNAVAILABLE` après 527 s. Engine simple : OK en 6 s. |
| Hypothèse « DNS peering / `roles/dns.peer` » | **Infirmée.** `roles/dns.peer` accordé à `gcp-sa-vertex-sandbox` (service agent des sandboxes, cité par la doc sandbox VPC-SC), `gcp-sa-aiplatform-re` et `gcp-sa-aiplatform` : 2 créations sur 2 en `UNAVAILABLE` (527 s, 531 s), grants retirés ensuite. Les créations du 2026-10-04 échouaient déjà sans peering. En projet autonome, la doc VPC connectivity ne demande pas `roles/dns.peer`, et `roles/agentgateway.serviceAgent` contient déjà `dns.networks.targetWithPeeringZone`. |
| Mise à jour de l'engine | Une mise à jour en place (mêmes gateways, donc sans archivage des révisions) ne change rien : 2 créations sur 2 en `UNAVAILABLE` (531 s, 530 s). |
| Cause racine | **Le sandbox est créé et fonctionnel en moins d'une seconde ; seule l'opération longue échoue**, après un délai fixe (521 à 526 s côté serveur sur douze échecs). Un sandbox dont la création a « échoué » exécute du code en 1,2 s ; celui qui sert aux e2e ci-dessous a lui aussi une opération de création en `UNAVAILABLE` (526 s). L'exécuteur ADK attend cette opération ; comme elle échoue, `operation.response` est vide et le SDK lève `ValueError("Error retrieving sandbox.")` au bout de ~9 min. Aucune interface PSC du sandbox dans l'attachement réseau de la gateway, aucune requête du sandbox dans `gateway_requests`, aucun refus de permission dans les journaux du projet. |
| Déclencheur côté plateforme | **Non identifié.** Une seule création a jamais réussi sur cet engine (2026-10-04 16:11). Entre-temps sont arrivés l'endpoint PSC pour Google APIs et la zone `run.app.` de `samples/base` (16:52), puis la première mise à jour de la gateway de sortie (16:55). Pour départager : retirer temporairement l'endpoint PSC et la zone, puis recréer un sandbox. |
| Documentation | Aucune limitation « sandbox + Agent Gateway » dans les pages Sandboxes, Route Agent Runtime traffic through Agent Gateway, Set up Agent Gateway with VPC connectivity et PSC interface. Le schéma v1beta1 montre que l'egress d'un sandbox (PSC-I, DNS peering) se règle sur un `SandboxEnvironmentTemplate`, et non sur l'engine. |
| Correctif | Sandbox pré-provisionné par `task sandbox` (`scripts/provision_sandbox.py`, lancé par `apply` et `e2e`) : création **sans attendre l'opération** (`wait_for_completion=False`), test d'exécution, TTL de 7 jours, suppression des anciens. Avant chaque requête, un `before_agent_callback` le retrouve par `display_name` et le place dans `session.state["sandbox_name"]`, que `AgentEngineSandboxCodeExecutor` lit en premier : plus aucune création dans le chemin de la requête. |
| Suppression de l'engine | Sur un engine jetable avec un sandbox enfant : `DELETE` sans `force` → `400 FAILED_PRECONDITION` « contains child resources: sandbox environments » ; avec `force=true` → engine et sandbox supprimés (404). `task destroy` aurait donc échoué (les sessions sont aussi des enfants) : `deletion_policy = "FORCE"` sur l'engine secured. |
| e2e | **6/6 en 40 s**, puis 6/6 en 47 s après le redéploiement final ; test sandbox seul : 3/3, de 7 à 15 s. Le test vérifie désormais la sortie `code_execution_result` (`24133`) et non le texte de la réponse : le modèle a une fois répondu `24,133`. L'appel `GET .../sandboxEnvironments/<ID>` de l'exécuteur passe par la gateway de sortie (`ALLOWED`). |

## geap-agent-secured-v2 : modules Cloud Foundation Fabric (2026-10-09)

| Sujet | Résultat |
|---|---|
| Modules | `geap-agent-gateway`, `geap-agent-runtime`, `gcs`, `cloud-function-v2`, `iam-service-account`, épinglés sur le commit `25d8d9a` de `master` : la release `v59.0.0` écrit `dns_peering_config.domain`, refusé par le provider `google` 8.5 (corrigé par `ccd4c1c95`, pas encore tagué). Voir l'ADR 005. |
| Plan | Deux valeurs inconnues au plan bloquaient le module gateway : l'id du network attachment (`count` du template) et l'id d'endpoint généré par Agent Registry (type de binding de `registry_iam_bindings`). Correctifs : attachment passé par `context` (`$psc_network_attachments:egress`) ; grants `iap.egressor` par endpoint gardés en ressources brutes. |
| Tests offline | Le module gateway configure ses propres providers : `mock_provider` ne les atteint pas et `terraform test` a appelé l'API réelle (refusée, projet fictif). Correctif : `override_module` sur les deux gateways. |
| Cohabitation avec secured | **Impossible** : `Error 429: Quota limit 'RegionalAgentGateways' has been exceeded. Limit: 2 in region europe-west1`. Terraform réessaie pendant 25 min avant d'échouer. Secured a été détruit pour libérer le quota. |
| IAM partagés | Les grants CMEK des service agents Cloud Functions / Cloud Run sont passés de secured à `samples/base` (blocs `removed` sans destruction côté secured) : la clé a gardé ses 5 membres pendant toute l'opération. |
| Build de la function | 1er apply : `Access to bucket gcf-v2-sources-... denied` pour le compte de build, dont le rôle Cloud Build venait d'être accordé (propagation IAM). Correctif : `time_sleep` de 60 s ; 2e apply OK en 52 s. |
| Destroy de secured | Bloqué sur la function : Cloud Functions supprime le package de l'image dans le dépôt Artifact Registry de `base`, qui a `immutable_tags = true` (`cannot delete package ... The repository has enabled tag immutability`). Terminé en levant l'immutabilité le temps de la suppression (`gcloud artifacts repositories update --no-immutable-tags`), puis rétablie par `task base:apply`. Le même blocage attend tout `destroy` d'un sample avec function. |
| **Sandbox natif sur l'engine v2** | **3 créations sur 3 réussies en 5 à 6 s** (opérations `5389284074932142080`, `4929916912940351488`, `6631151672179556352`), juste après la création de l'engine puis 20 min plus tard. L'engine est lié à deux gateways, dans le même projet et la même région, avec l'endpoint PSC `240.0.0.10`, la zone `run.app.` et le DNS peering `run.app.` sur le template. **La liaison à une gateway, l'endpoint PSC et le DNS peering ne sont donc pas en cause.** Ce qui distingue l'engine secured en échec : ses gateways avaient été mises à jour (bascule de template de connectivité, première fois le 2026-10-04 à 16:55), l'API de création (`v1` contre `v1alpha1` via le module), l'âge de l'engine (2026-10-01) et le provider (8.5.0 contre 8.6.0). |
| Requêtes client → agent | **Faux problème, corrigé le 2026-10-10** : voir la section suivante. |

## geap-agent-secured-v2 : « 404 » client → agent (2026-10-10)

| Sujet | Résultat |
|---|---|
| **Cause** | **Artefact de mesure, pas un défaut de la plateforme.** Les sondes `curl` étaient lancées depuis zsh avec une URL `".../reasoningEngines/$ENG:streamQuery?alt=sse"`. zsh lit `:s` comme un modificateur de substitution (`:s/ancien/nouveau/`, ici avec `t` pour délimiteur) et retire `:streamQuery?alt=sse` de l'URL : le POST visait `.../reasoningEngines/<ID>`, d'où un `404` HTML du frontal (`server: ESF`), sans que la requête n'atteigne jamais l'agent. Même effet avec `:query` (modificateur `:q`). Preuve : avec `${ENG}:streamQuery` (accolades), la même requête répond `200` (« Brussels ») ; un engine inexistant répond, lui, un `404` JSON du backend (`server: scaffolding on HTTPServer2`). Les appels Python (`task invoke`, `task e2e`) n'ont jamais été touchés. |
| Conclusions retirées | « Requêtes en 404 après quelques minutes », « gateway d'ingress créée par l'API `v1alpha1` sans route vers l'agent », « l'enregistrement de l'engine dans Agent Registry ne change rien » : toutes reposaient sur ces sondes. L'échec du test sandbox du 2026-10-09 20:12 (`assert False` en 1,4 s) venait des grants d'egress pas encore propagés juste après la création (`POST .../sessions 403 DENIED` dans le journal de la gateway). |
| Essais faits pendant le diagnostic | Tous sans effet sur le symptôme (qui n'existait pas), puis annulés : endpoint `cloudresourcemanager.mtls.googleapis.com/` (le refus IAP de `GetProject` au démarrage reste un avertissement non bloquant), retrait de `registries` sur l'ingress, gateway d'ingress en ressources brutes `v1`, suppression des révisions archivées, engine recréé via l'API `v1` (nouvel id `4648306352702095360`). La gateway d'ingress brute a été réadoptée par le module (`terraform state rm` + `terraform import`) : même nom, donc l'engine n'a pas eu à être relié. |
| Révisions | Un engine créé par l'API `v1beta1` (provider `google-beta`, donc le module Fabric) a des révisions d'exécution (`revisionGarbageCollectionStrategy.keepNLatest = 100`), contrairement à un engine créé en `v1`. Chaque changement de liaison de gateway archive toutes les révisions précédentes. Une révision ne peut pas être appelée directement quand une gateway est liée : `400 FAILED_PRECONDITION ... cannot be called by runtime revision because Agent Gateway is configured`. |
| Provider | Sur une mise à jour en place de l'engine, `google-beta` 8.6 retire du plan un `client_to_agent_config` dont l'id de gateway n'est connu qu'après l'apply (plan `no-op`, liaison absente). Correctif : id construit depuis le nom de la gateway (`agent.tf`). |
| Ordre de destruction | Retirer une gateway de la configuration en gardant l'engine : Terraform supprime la gateway avant de mettre l'engine à jour, l'API refuse (`already being used by resource(s) .../reasoningEngines/...`) et le provider réessaie toutes les 10 s pendant ~30 min. Il faut délier d'abord (`-target=module.agent`). |
| Sandbox natif | Nouvel engine (créé en `v1`, gateway d'ingress créée en `v1`, egress en `v1alpha1`) : **3/3 créations OK en 6 s** (opérations `7707969379958259712`, `1943361856924024832`, `3784208204611715072`). Avec l'engine de la veille : 6/6 sur deux engines liés à des gateways neuves. L'API de création (engine ou gateways) n'est donc pas un facteur. |
| e2e | `task secured-v2:e2e` : **6/6 en 43 s** (question simple, écriture dans le workspace, refus hors workspace, function, code dans le sandbox, blocage Model Armor). |
