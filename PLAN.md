# PLAN — Samples Gemini Enterprise Agent Platform (GEAP)

> Plan d'exécution destiné à **Claude Sonnet 5.5** (Claude Code).
> Source : `PROMPT.md` (gitignoré). Rédigé le 2026-10-01 à partir de la doc
> GEAP, du provider Terraform `google`/`google-beta` (branche `main`) et des
> codelabs officiels. Tout ce qui est marqué 🔎 **n'est pas confirmé** et doit
> être validé en Phase 0 avant d'être codé.

---

## 0. Mode d'emploi pour l'agent exécutant (à lire en premier)

1. **Une phase = une session = un commit** (Conventional Commit). Ne pas
   enchaîner deux phases sans que l'utilisateur ait validé la précédente.
2. Avant chaque phase : relire `AGENT.md`, les rules globales
   (`~/.claude/rules/*.md`), la section **§3 Conventions** de ce plan, et
   `docs/VERIFICATION.md` (produit en Phase 0).
3. **Ne jamais inventer** un nom de ressource, un argument Terraform, un flag
   gcloud ou une signature SDK. Procédure obligatoire avant d'écrire :
   - Terraform : `terraform providers schema -json | jq '.provider_schemas[].resource_schemas | keys[]' | grep <motif>`
     puis inspecter les attributs de la ressource.
   - gcloud : `gcloud [alpha|beta] <groupe> <commande> --help`.
   - Python : `python -c "import <pkg>, inspect; print(inspect.signature(<obj>))"` dans le `.venv` du sample.
   - Versions : `pip index versions <pkg>` / registry Terraform / `gh api repos/<owner>/<repo>/releases/latest` — jamais de mémoire.
4. **Ordre de mécanisme imposé par le prompt** : Terraform → sinon SDK Python
   (ADK / `agentplatform`) → sinon CLI (`gcloud`, `agents-cli`). La matrice §2
   donne le mécanisme attendu ; si la Phase 0 le contredit, mettre à jour la
   matrice **et** `docs/VERIFICATION.md` avant de coder.
5. **Points STOP** (🛑) : s'arrêter, résumer, attendre l'accord explicite de
   l'utilisateur. Obligatoire avant tout `task apply` (coût) et en fin de
   Phase 0.
6. Commandes exécutées **uniquement** depuis la racine du repo ou le dossier du
   sample concerné (rule `security-prompt`). Fichiers temporaires dans le
   scratchpad de session, jamais `/tmp`.
7. Zéro secret / project ID / numéro de projet / org ID dans le code, la doc
   ou les commits. Placeholders : `my-gcp-project-id`, `123456789012`.
8. Definition of done de chaque phase : `pre-commit run --all-files` vert +
   `task test` vert + README/TFDOCS/CHANGELOG à jour.

---

## 1. Décisions d'architecture (à formaliser en ADR, Phase 1)

| # | Décision | Justification | Alternative rejetée |
|---|---|---|---|
| D1 | **Région unique `europe-west1`** pour toutes les ressources régionales ; endpoints régionaux (`europe-west1-aiplatform.googleapis.com`, `modelarmor.europe-west1.rep.googleapis.com`) ; jamais `global` pour le modèle. | Souveraineté max. Runtime, Sandboxes, Gateway, Semantic governance supportés en `europe-west1`. | Location `global` du modèle (meilleure dispo, mais sortie de région). |
| D2 | **Agent Identity** (`spec.identity_type = "AGENT_IDENTITY"`) pour les deux agents, pas de service account. | Identité SPIFFE gérée, pas de clé, obligatoire pour Agent Gateway et Semantic governance. Principal IAM dérivé de `spec[0].effective_identity` → pas d'org ID en dur. | SA dédié (OK pour `simple`, mais incompatible gateway). |
| D3 | **Agent déployé par Terraform** (`google_vertex_ai_reasoning_engine` + `source_code_spec.inline_source` + `python_spec`). `agents-cli` sert au **scaffold, run local, eval** — **pas** au deploy. | Un seul propriétaire de l'état (Terraform) ; évite la dérive entre `agents-cli deploy` et le state. Pas de Dockerfile requis avec `python_spec`. | `agents-cli deploy` (génère sa propre infra Terraform → double propriété). |
| D4 | **Deux Agent Gateways** dans `geap-agent-secured` : `CLIENT_TO_AGENT` (ingress) + `AGENT_TO_ANYWHERE` (egress, default-deny). | Ce sont deux modes distincts (`google_managed.governed_access_path`), référencés séparément dans `deployment_spec.agent_gateway_config.{client_to_agent_config,agent_to_anywhere_config}`. | Un seul gateway (impossible de couvrir ingress + egress). |
| D5 | **Model Armor au niveau Gateway ingress** : `google_network_services_authz_extension` (`service = "modelarmor.europe-west1.rep.googleapis.com"`) + `google_network_security_authz_policy` (`policy_profile = "CONTENT_AUTHZ"`, `action = "CUSTOM"`) ciblant le gateway `CLIENT_TO_AGENT`. Le gateway inspecte la requête `query/streamQuery` (entrée utilisateur) **et** la réponse (sortie agent). | 100 % Terraform, zéro code applicatif, conforme à « en entrée et en sortie de l'agent ». | Callbacks ADK `before_model_callback`/`after_model_callback` appelant `sanitizeUserPrompt`/`sanitizeModelResponse` → **fallback** uniquement si V5 (Phase 0) échoue. Mêmes templates, ajout d'un fichier `app/guardrails.py`. |
| D6 | **Accès bucket restreint à un path via Managed Folder** (`google_storage_managed_folder` `agent-workspace/` + `google_storage_managed_folder_iam_member` `roles/storage.objectUser`). | Les conditions IAM `resource.name.startsWith` ne filtrent pas `storage.objects.list` (évalué au niveau bucket) ; le managed folder donne list/read/write sur le seul préfixe. Les agent identities **ne peuvent pas** recevoir les rôles `storage.legacyBucket*`. | IAM condition `startsWith("projects/_/buckets/<b>/objects/agent-workspace/")` → **fallback** si V7 échoue. |
| D7 | **Cloud Run function (gen2) appelée en HTTP** via le gateway egress : URL enregistrée comme *endpoint* Agent Registry + `roles/iap.egressor` + `roles/run.invoker` pour le principal de l'agent. Ingress `ALLOW_INTERNAL_ONLY`. | Démontre le contrôle egress GEAP (registry + IAM agent policy). | Déclenchement Eventarc par écriture dans `agent-workspace/triggers/` → **fallback** si V8 (ID token Agent Identity / ingress interne) échoue. |
| D8 | **Sandbox** : `AgentEngineSandboxCodeExecutor(agent_engine_resource_name=…)` construit au runtime à partir des variables d'env injectées par Agent Runtime (création auto du sandbox, hermétique, sans réseau). | Pas de cycle Terraform (le sandbox est un enfant du reasoning engine). | Création explicite via SDK `agentplatform` puis injection du nom en env → cycle d'apply en 2 passes ; fallback si V9 échoue. |
| D9 | **Agent Policy** = (a) IAM agent policies `roles/iap.egressor` (obligatoire, c'est l'allowlist egress) + (b) **Semantic governance** (Preview) en `DRY_RUN` puis `ENFORCE`, derrière un flag `enable_semantic_governance` (défaut `false`, coût LLM). | Couvre « GEAP Agent Policy » sans imposer une feature Preview payante par défaut. | Semantic governance toujours actif. |
| D10 | **CMEK** : une clé unique (base) pour GCS, Artifact Registry, reasoning engines (`encryption_spec.kms_key_name`), Cloud Functions. | Exigence prompt « clé KMS unique ». | Une clé par service (plus fin, plus cher, hors scope). |
| D11 | **Pas de Cloud NAT**. Accès Google APIs via Private Google Access (+ option PSC Google APIs endpoint). | Aucune sortie internet nécessaire ; coût ~0 ; surface réduite. | NAT (~30 €/mois + data, inutile). |

---

## 2. Matrice composant → mécanisme

Légende stade : GA / Preview / 🔎 à confirmer. « V#» = vérification Phase 0.

| Composant | Mécanisme attendu | Ressource / commande | Stade | europe-west1 | Vérif |
|---|---|---|---|---|---|
| KMS keyring + clé | Terraform (module) | `terraform-google-modules/kms/google` | GA | ✅ | — |
| VPC, subnets, firewall | Terraform (module) | `terraform-google-modules/network/google` | GA | ✅ | — |
| Network attachments (PSC-I) | Terraform | `google_compute_network_attachment` | GA | ✅ | — |
| Agent Runtime | Terraform | `google_vertex_ai_reasoning_engine` (`source_code_spec`, `python_spec`, `encryption_spec`, `deployment_spec.psc_interface_config`, `agent_gateway_config`) | GA (`agent_gateway_config` : 🔎 google vs google-beta) | ✅ | V2 |
| Agent Identity | Terraform (attribut) | `spec.identity_type = "AGENT_IDENTITY"`, sortie `spec[0].effective_identity` | GA 🔎 | ✅ (trust domain `agents.global.*`, métadonnée globale) | V3 |
| Agent Gateway ×2 | Terraform | `google_network_services_agent_gateway` (+ `google_network_services_agent_connectivity_template` pour l'egress réseau) | 🔎 | ✅ | V4 |
| Model Armor templates | Terraform | `google_model_armor_template` | GA | ✅ | — |
| Model Armor ↔ Gateway | Terraform | `google_network_services_authz_extension` + `google_network_security_authz_policy` (`CONTENT_AUTHZ`) | 🔎 sur `CLIENT_TO_AGENT` | ✅ | V5 |
| Agent Registry (services/endpoints) | Terraform | `google_agent_registry_service`, `google_agent_registry_binding` (présents dans `google` 8.5.0) | 🔎 Preview probable | ✅ | V6 ✅ |
| IAM agent policies (egress) | Terraform | `google_iap_agent_registry_endpoint_iam_member` (rôle `roles/iap.egressor`) | 🔎 | ✅ | V6 ✅ |
| Semantic governance | Terraform | `google_vertex_ai_semantic_governance_policy_engine` + `google_vertex_ai_semantic_governance_policy` + authz ext/policy (sur `agw-egress` uniquement) | Preview | ✅ | V10 ✅ |
| Sandbox code execution | ADK Python | `AgentEngineSandboxCodeExecutor` | GA (sept. 2026) | ✅ | V9 |
| GCS bucket + managed folder | Terraform | `google_storage_bucket`, `google_storage_managed_folder(_iam_member)` | GA | ✅ | V7 |
| Cloud Run function | Terraform | `google_cloudfunctions2_function` | GA | ✅ | V8 |
| Agent code | ADK Python | `google-adk` | GA | — | V1 |
| Dev local / eval | `agents-cli` | `uvx google-agents-cli …` | 🔎 | — | V11 |

---

## 3. Conventions (checklist appliquée à chaque sample)

- [ ] Fichiers Terraform par domaine : `main.tf` (bloc `terraform{}`, providers, APIs, locals de nommage), `variables.tf`, `outputs.tf`, `backend.tf`, puis `network.tf`, `iam.tf`, `kms.tf`, `agent.tf`, `gateway.tf`, `model_armor.tf`, `storage.tf`, `function.tf`…
- [ ] Provider `google` **et** `google-beta` épinglés (`~> X.Y`, version réelle vérifiée), `required_version` épinglé.
- [ ] `default_labels = { project = "gcp-samples_<sample>", env = var.env, managed-by = "terraform" }` sur **les deux** providers. Underscore, jamais de `/`.
- [ ] Toute variable : `type` + `description` ; `validation {}` sur `region` (doit commencer par `europe-west1`), `model`, `min/max_instances` (bornes coût), noms.
- [ ] Outputs décrits, `sensitive = true` si besoin.
- [ ] Backend GCS, préfixe `samples/<sample>` ; samples consomment `base` via `terraform_remote_state`.
- [ ] `tests/*.tftest.hcl` à la racine du sample avec `mock_provider "google"` + `mock_provider "google-beta"` → **offline**, exécuté en CI sans credentials. Deux pièges :
  - `data.terraform_remote_state.base` n'est **pas** couvert par `mock_provider` (provider intégré `terraform`) → utiliser `override_data { target = data.terraform_remote_state.base values = { outputs = { kms_key_id = "…", network_id = "…", … } } }`.
  - `filebase64()` est évalué au plan même sous mock, et `build/` est gitignoré → chemin d'archive en variable (`var.agent_source_archive`, défaut `build/agent_src.tar.gz`) ; les tests passent un fixture committé `tests/fixtures/agent_src.tar.gz` (quelques octets).
- [ ] Python : `.venv` local, `requirements.in` → `requirements.txt` épinglé (`uv pip compile`), `ruff`, `pyright`, `pytest` 100 % offline (mocks, aucune vraie requête LLM).
- [ ] `config.py` (env validé), `logger.py` (pas de `print`), retry `tenacity` sur appels externes.
- [ ] `README.md` au squelette doc-practices + marqueurs `<!-- BEGIN_TF_DOCS -->`/`<!-- END_TF_DOCS -->` dans `TFDOCS.md`.
- [ ] Entrée `CHANGELOG.md` du jour (une seule par date).
- [ ] Ignore KICS/Trivy localisé, commenté avec la raison.
- [ ] `.env.example` en placeholders, `.env` gitignoré.

---

## 4. Arborescence cible

```text
.
├── .github/workflows/
│   ├── ci.yml                    # pre-commit, tests TF/Python, KICS, Trivy (path-filtered)
│   └── deploy.yml                # workflow_dispatch, WIF, plan/apply manuel par sample (optionnel)
├── .pre-commit-config.yaml
├── .tflint.hcl
├── kics.config                   # exclusions commentées
├── trivy.yaml
├── Taskfile.yml                  # orchestration racine (base d'abord à l'apply, en dernier au destroy)
├── README.md
├── CHANGELOG.md
├── docs/
│   ├── VERIFICATION.md           # résultats Phase 0 (source de vérité des 🔎)
│   └── adr/001..00N-*.md
└── samples/
    ├── base/
    │   ├── Taskfile.yml  README.md  TFDOCS.md  .env.example
    │   ├── main.tf  backend.tf  variables.tf  outputs.tf
    │   ├── apis.tf  kms.tf  network.tf  logging.tf  artifact_registry.tf  cicd.tf  budget.tf
    │   └── tests/base.tftest.hcl
    ├── geap-agent-simple/
    │   ├── Taskfile.yml  README.md  TFDOCS.md  .env.example
    │   ├── main.tf  backend.tf  variables.tf  outputs.tf  agent.tf  iam.tf
    │   ├── app/                  # racine de l'archive source_code_spec
    │   │   ├── agent.py  config.py  logger.py  requirements.txt
    │   ├── requirements.in  requirements-dev.txt  pyproject.toml
    │   ├── scripts/package.py    # tar.gz déterministe → build/agent_src.tar.gz
    │   ├── scripts/invoke.py     # appel de l'agent déployé
    │   └── tests/{test_agent.py, agent.tftest.hcl, fixtures/agent_src.tar.gz}
    └── geap-agent-secured/
        ├── Taskfile.yml  README.md  TFDOCS.md  .env.example
        ├── main.tf  backend.tf  variables.tf  outputs.tf
        ├── network.tf            # network attachments (agent PSC-I, gateway egress)
        ├── storage.tf            # bucket + managed folder agent-workspace/
        ├── function.tf           # Cloud Run function + SA runtime/build
        ├── model_armor.tf        # templates + authz extension + authz policy
        ├── gateway.tf            # gateway ingress + egress + connectivity template
        ├── agent.tf  iam.tf
        ├── app/  agent.py  tools.py  config.py  logger.py  requirements.txt
        ├── function_src/main.py  requirements.txt
        ├── scripts/
        │   ├── package.py  invoke.py
        │   ├── registry.sh       # idempotent : describe || create (si pas de TF/SDK)
        │   ├── agent_policies.sh # iap.egressor (si pas de TF)
        │   └── semantic_gov.sh   # optionnel, flag
        └── tests/{test_tools.py, test_agent.py, secured.tftest.hcl, e2e/}
```

---

## 5. Phases

### Phase 0 — Bootstrap & vérifications (spikes) 🛑

**Objectif** : lever les 🔎 avant d'écrire du code durable.

1. `git init -b main` (le dossier n'est pas un repo git). Vérifier que `.gitignore` couvre `.env`, `*.tfstate*`, `build/`, `.venv/` (ajouter `build/`).
2. Vérifier les outils et noter les versions : `terraform`, `tflint`, `terraform-docs`, `pre-commit`, `task`, `gcloud` (+ composants alpha/beta), `uv`, `python3.13`, `kics` (ou image podman), `trivy`, `gh`, `podman`.
3. Installer `agents-cli` en local : `uvx google-agents-cli setup` puis `agents-cli info` / `--help`.
4. Exécuter les vérifications ci-dessous, **en lecture seule** (help, schema, describe). Aucune création de ressource payante sans 🛑.
   - **V-static** (V1, V2, V4, V5, V6, V10, V11, V13) : vérifiables via schema / `--help` / doc → **bloquants pour la Phase 1**.
   - **V-runtime** (V3, V7, V8, V9, V12) : impossibles à prouver sans ressource déployée → en Phase 0, noter seulement ce que dit la doc et le statut « différé en Phase N ». Ils deviennent des **critères d'acceptation** de la phase qui crée la ressource : V12 → Phase 3 ; V3, V7, V8, V9 → Phase 5. Ne pas boucler pour les « prouver » en Phase 0.

| ID | Question | Comment vérifier |
|---|---|---|
| V1 | Versions courantes `google-adk`, `google-cloud-aiplatform`/`agentplatform`, provider `google`/`google-beta` | `pip index versions`, registry TF |
| V2 | `agent_gateway_config`, `identity_type`, `encryption_spec`, `psc_interface_config` présents dans `google` GA ou seulement `google-beta` ? Compatibilité **PSC-I + agent_gateway_config** sur un même engine ? | `terraform providers schema -json` ; doc runtime VPC |
| V3 | Format de `effective_identity` → principal `principal://<effective_identity>` ? | Doc + describe d'un engine test (après 🛑) |
| V4 | `google_network_services_agent_gateway` accepte `location = "europe-west1"` pour les deux modes ; `registries` = `//agentregistry.googleapis.com/projects/<p>/locations/europe-west1` | schema + `gcloud network-services agent-gateways create --help` |
| V5 | `CONTENT_AUTHZ` + extension Model Armor supportés sur un gateway **`CLIENT_TO_AGENT`** ? Clés `metadata` pour référencer les templates ? | Doc Agent Gateway / Model Armor integration, codelab `cloudnet-agent-gateway` |
| V6 | Ressource TF ou SDK Python pour Agent Registry et IAM agent policies (`iap.egressor`) ? Sinon flags exacts `gcloud [alpha] agent-registry services create`, `gcloud iap web set-iam-policy --resource-type=agent-registry` | schema TF, PyPI, `--help` |
| V7 | Managed folder IAM accepte un principal Agent Identity | doc GCS managed folders + test |
| V8 | Agent Identity peut obtenir un **ID token** pour Cloud Run (`google.oauth2.id_token.fetch_id_token`) ; gateway egress peut joindre un Cloud Run `ALLOW_INTERNAL_ONLY` ; rôle de `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES` | doc Agent Identity / Gateway |
| V9 | Agent Runtime injecte-t-il `GOOGLE_CLOUD_AGENT_ENGINE_ID` (ou équivalent) ? `AgentEngineSandboxCodeExecutor` compatible avec des function tools sur le même `LlmAgent` ? | doc ADK, source `google/adk-python` |
| V10 | Semantic governance : flags `gcloud beta ai semantic-governance-*`, coût, format `--agent=projects/…/agents/<id>` | `--help`, pricing |
| V11 | Rôle exact d'`agents-cli` : `create`, `run`, `eval` ; template ADK généré (structure `app/agent.py`, `root_agent`) | `agents-cli --help` |
| V12 | Modèle par défaut (`gemini-3.5-flash` ?) **disponible sur l'endpoint régional `europe-west1`** (pas seulement `global`) | doc locations modèles ; appel `generateContent` régional après 🛑 |
| V13 | Endpoints à allowlister côté egress (aiplatform régional + mTLS, storage, logging, telemetry, monitoring, iamcredentials, secretmanager, Cloud Run URL) | doc « Route Agent Runtime traffic through Agent Gateway » |

5. Écrire `docs/VERIFICATION.md` : tableau `ID | Résultat | Source (URL/commande) | Impact sur le plan`. Mettre à jour §1/§2 si une décision bascule sur son fallback.

**Critères d'acceptation** : les 8 V-static ont un résultat sourcé ; les 5 V-runtime portent « différé en Phase N » + ce que dit la doc ; aucune ressource créée.
**🛑 STOP** : présenter `VERIFICATION.md` et les éventuels basculements (D5/D6/D7/D8) à l'utilisateur.
**Commit** : `chore: bootstrap repository and record GEAP verification results`

---

### Phase 1 — Industrialisation du repo

**Fichiers** : `Taskfile.yml`, `.pre-commit-config.yaml`, `.tflint.hcl`, `kics.config`, `trivy.yaml`, `.github/workflows/ci.yml`, `README.md`, `CHANGELOG.md`, `docs/adr/001..004`.

1. **pre-commit** (tous les `rev:` épinglés à la dernière release vérifiée) : hygiene (`trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-added-large-files`), `antonbabenko/pre-commit-terraform` (`terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_docs` → `TFDOCS.md`), `gitleaks`, `ruff` + `ruff-format`, `conventional-pre-commit` (stage `commit-msg`).
2. **Taskfile racine** (v3, `default: task --list`) :
   - `bootstrap` : crée le bucket de state `<project>-tfstate` en `europe-west1` (idempotent : `describe || create`, versioning, uniform access, public access prevention).
   - `includes:` des 3 samples ; `apply-all` (base → simple → secured), `destroy-all` (ordre inverse, desc `WARNING: deletes …`).
   - `lint` (pre-commit), `scan` (deps `kics`, `trivy`), `test-all`.
   - `kics` : `podman run --rm -v $PWD:/path:ro docker.io/checkmarx/kics:<tag épinglé> scan -p /path --config /path/kics.config`.
   - `trivy` : `trivy config --severity HIGH,CRITICAL --exit-code 1 .` + `trivy fs --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 1 .`
3. **CI GitHub Actions** `ci.yml` :
   - Déclencheurs `push`/`pull_request` avec `paths:` par sample + config partagée.
   - Jobs : `pre-commit` ; `terraform-test` (matrix `[base, geap-agent-simple, geap-agent-secured]`, `terraform init -backend=false` + `terraform test` avec `mock_provider`) ; `python-test` (matrix simple/secured, `uv`, `pytest`, `pyright`) ; `kics` (SARIF → `github/codeql-action/upload-sarif`) ; `trivy` (config + fs, SARIF).
   - Toutes les actions **épinglées par SHA** avec la version en commentaire (résoudre via `gh api repos/<o>/<r>/git/ref/tags/<tag>`).
   - `permissions:` minimales (`contents: read`, `security-events: write` pour SARIF).
   - Cache : `TF_PLUGIN_CACHE_DIR`, uv, pre-commit.
4. **ADR** : `001-terraform-first-mechanism-matrix`, `002-agent-identity`, `003-model-armor-at-gateway`, `004-dual-agent-gateway`.
5. **README racine** : pitch, prérequis outillés, Getting Started (`task bootstrap`, `task apply-all`), tableau `| Name | Description | README |`, arbre annoté, section sécurité & souveraineté.

**Critères** : `pre-commit run --all-files` vert ; `task --list` lisible ; `actionlint` (si dispo) OK sur les workflows.
**Commit** : `chore: add taskfile, pre-commit, kics/trivy scans and github ci`

---

### Phase 2 — `samples/base`

**Ressources** :

| Fichier | Contenu |
|---|---|
| `apis.tf` | `google_project_service` (`disable_on_destroy = false`) : aiplatform, cloudkms, compute, dns, storage, artifactregistry, run, cloudfunctions, cloudbuild, eventarc, modelarmor, networkservices, networksecurity, agentregistry, iap, logging, monitoring, cloudtrace/telemetry, iamcredentials, secretmanager, billingbudgets. |
| `kms.tf` | Module KMS : keyring `kr-gcp-samples` + clé unique `key-gcp-samples` en `europe-west1`, rotation 90 j, `prevent_destroy = true`. Identités de service (`google_project_service_identity` ou format `service-<num>@…`) + `roles/cloudkms.cryptoKeyEncrypterDecrypter` **sur la clé** pour : storage, artifactregistry, aiplatform (`gcp-sa-aiplatform`), reasoning engine (`gcp-sa-aiplatform-re`), cloudfunctions/run, eventarc si utilisé. 🔎 liste exacte selon V2. |
| `network.tf` | Module network : VPC `vpc-gcp-samples` (custom), subnet `snet-workloads-ew1` `10.10.0.0/24` (Private Google Access, flow logs 0.5), subnet `snet-psc-attach-ew1` `10.10.1.0/28` réservé aux network attachments. Firewall : deny-all ingress explicite (priorité basse, loggé) ; règles egress documentées. **Pas de NAT**. Option `enable_psc_google_apis` : endpoint PSC Google APIs + zone DNS privée `googleapis.com`. |
| `logging.tf` | Bucket de logs `europe-west1` + redirection du sink `_Default` (souveraineté des logs), rétention 30 j. |
| `artifact_registry.tf` | Repo Docker `europe-west1`, CMEK (utilisé par les builds Cloud Functions). |
| `cicd.tf` | Option `enable_github_wif` (défaut `false`) : pool/provider WIF, `attribute_condition` sur `assertion.repository == var.github_repository`, SA de déploiement. |
| `budget.tf` | `google_billing_budget` (seuils 50/90/100 %), `billing_account` en variable. |
| `outputs.tf` | `kms_key_id`, `network_id`, `network_name`, `subnet_workloads_id`, `subnet_psc_attach_id`, `artifact_registry_repo`, `region`. |

**Org policy** (optionnelle, nécessite droits org) : `constraints/gcp.resourceLocations = in:europe-west1-locations` au niveau projet, derrière `enable_location_policy` (défaut `false`) — documenter dans le README.

**Tests** `tests/base.tftest.hcl` (`mock_provider`) : région forcée `europe-west1` ; clé avec `rotation_period` ; aucune ressource NAT ; subnets avec Private Google Access ; labels `project = gcp-samples_base`.

**Critères** : `task test` vert ; `task plan` propre ; KICS/Trivy sans HIGH/CRITICAL non justifié.
**🛑 STOP** avant `task apply` (coûts : KMS ~0,06 $/version/mois, budget, logs).
**Commit** : `feat(base): add shared kms key, belgium vpc and project foundations`

---

### Phase 3 — `samples/geap-agent-simple`

**Agent** (`app/agent.py`) : `LlmAgent` ADK `root_agent`, modèle `var.model` (défaut issu de V12), instruction courte « réponds de façon concise à la question ». Aucun outil.
`config.py` lit `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION=europe-west1`, `GOOGLE_GENAI_USE_VERTEXAI=true`, `MODEL`.

**Terraform** (`agent.tf`) :
```hcl
resource "google_vertex_ai_reasoning_engine" "agent" {
  display_name = local.agent_name
  region       = var.region
  encryption_spec { kms_key_name = data.terraform_remote_state.base.outputs.kms_key_id }
  spec {
    agent_framework = "google-adk"
    identity_type   = "AGENT_IDENTITY"
    source_code_spec {
      inline_source { source_archive = filebase64(var.agent_source_archive) }
      python_spec {
        version           = "3.13"
        entrypoint_module = "agent"
        entrypoint_object = "root_agent"
      }
    }
    deployment_spec {
      min_instances = var.min_instances   # validation 0..1
      max_instances = var.max_instances   # validation 1..3
      env {
        name  = "MODEL"
        value = var.model
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }
    }
  }
}
```
> Syntaxe indicative : vérifier chaque attribut contre le schema (V2) — notamment si `min_instances = 0` est accepté.

`iam.tf` : `roles/aiplatform.user` au principal `principal://${...spec[0].effective_identity}` (format V3) — rien d'autre.

**Packaging** : `scripts/package.py` → `build/agent_src.tar.gz` **déterministe** (`tarfile`, mtime/uid/gid fixes, tri des noms) pour éviter un diff Terraform à chaque plan. Task `package` en `deps:` de `plan`/`apply`.

**Taskfile sample** : `setup` (venv + uv), `run` (local via `agents-cli`/`adk web`, selon V11), `package`, `init/plan/apply/destroy`, `invoke` (`scripts/invoke.py` : `query` sur l'engine, affiche réponse + durée + tokens), `test`, `lint`.

**Tests** : `test_agent.py` (construction de l'agent, instruction, modèle depuis l'env ; LLM mocké) ; `agent.tftest.hcl` (identity `AGENT_IDENTITY`, région, CMEK, bornes instances, labels ; `override_data` sur le remote state, fixture `tests/fixtures/agent_src.tar.gz`).

**Critères** : tests verts ; `task invoke -- "Quelle est la capitale de la Belgique ?"` répond (après apply) ; logs dans le bucket `europe-west1`.
**V-runtime à clore ici** : **V12** (le modèle répond via l'endpoint régional `europe-west1`) ; noter aussi la valeur réelle de `effective_identity` (pré-requis V3). Mettre à jour `docs/VERIFICATION.md`.
**🛑 STOP** avant `task apply`.
**Commit** : `feat(geap-agent-simple): deploy adk agent on agent runtime with agent identity`

---

### Phase 4 — `geap-agent-secured` : fondations infra

1. `storage.tf` : bucket `<project>-geap-secured-data` `europe-west1`, CMEK, uniform access, `public_access_prevention = "enforced"`, versioning, lifecycle. `google_storage_managed_folder` `agent-workspace/`.
2. `function.tf` : `google_cloudfunctions2_function` `fn-agent-action` (python313, `europe-west1`), source zippée (`archive_file`) dans un bucket sources CMEK, `docker_repository` = repo AR de base, `kms_key_name`, **SA runtime dédié sans rôle**, **SA build dédié**, `ingress_settings = "ALLOW_INTERNAL_ONLY"`, `all_traffic_on_latest_revision = true`, max instances 1. Fonction triviale (ex. renvoie un accusé + horodatage, journalise le payload).
3. `network.tf` : deux `google_compute_network_attachment` sur `snet-psc-attach-ew1` (agent PSC-I ; gateway egress), `connection_preference = "ACCEPT_AUTOMATIC"`. Zone DNS privée si nécessaire au peering (V4/V13).
4. `model_armor.tf` : `google_model_armor_template` `ma-agent-io` en `europe-west1` : `pi_and_jailbreak_filter_settings` (`MEDIUM_AND_ABOVE`), `malicious_uri_filter_settings`, `rai_settings` (4 catégories), `sdp_settings.basic_config` ; `template_metadata` avec logging des opérations activé.
5. `gateway.tf` :
   - `google_network_services_agent_gateway` `agw-ingress` : `CLIENT_TO_AGENT`, `location = var.region`, `registries = ["//agentregistry.googleapis.com/projects/${var.project_id}/locations/${var.region}"]`.
   - `google_network_services_agent_connectivity_template` (`AGENT_TO_ANYWHERE`, `egress_network_config.network_attachment` + `dns_peering_config`) puis `google_network_services_agent_gateway` `agw-egress` (`AGENT_TO_ANYWHERE`, `agent_connectivity_template = …`). ⚠️ L'exemple du provider construit cette référence avec le **numéro** de projet (`projects/${data.google_project.project.number}/locations/…/agentConnectivityTemplates/…`), pas l'ID — erreur silencieuse sinon.
   - Modèle Armor (D5) : `google_network_services_authz_extension` (`service = "modelarmor.${var.region}.rep.googleapis.com"`, `metadata` → template, selon V5) + `google_network_security_authz_policy` (`policy_profile = "CONTENT_AUTHZ"`, `action = "CUSTOM"`, `target.resources = [agw-ingress]`).
   - Option : même couple sur `agw-egress` filtré sur `:generateContent|:streamGenerateContent` (défense en profondeur, désactivé par défaut).

**Tests** `secured.tftest.hcl` : bucket non public + CMEK ; function ingress interne ; aucun rôle projet pour le SA function ; gateways en `europe-west1` ; authz policy `CONTENT_AUTHZ`.

**🛑 STOP** : présenter l'estimation de coût §7 avant tout apply.
**Commit** : `feat(geap-agent-secured): add data bucket, cloud run function, model armor and agent gateways`

---

### Phase 5 — `geap-agent-secured` : agent & runtime

1. `app/tools.py` (function tools ADK, typés, docstrings précises) :
   - `read_workspace_file(path: str) -> str` / `write_workspace_file(path: str, content: str) -> str` : normalisation du chemin, rejet de `..`, absolu, et de tout ce qui n'est pas sous `agent-workspace/` (**défense en profondeur**, l'IAM reste la barrière réelle). `google-cloud-storage`, endpoint régional si disponible.
   - `trigger_action(payload: dict) -> dict` : POST HTTPS sur `FUNCTION_URL` avec ID token (V8), `tenacity` (backoff exponentiel, erreurs transitoires seulement), timeout 10 s.
2. `app/agent.py` : `LlmAgent` `root_agent` avec les 3 tools + `code_executor=AgentEngineSandboxCodeExecutor(agent_engine_resource_name=<construit depuis l'env>)` (D8). Si V9 indique l'incompatibilité tools + code executor : sous-agent `coder` (avec executor) exposé via `AgentTool`.
3. `agent.tf` : comme Phase 3 + `deployment_spec.psc_interface_config { network_attachment = … }` + `agent_gateway_config { client_to_agent_config { agent_gateway = agw-ingress.id } agent_to_anywhere_config { agent_gateway = agw-egress.id } }` + env `BUCKET`, `FUNCTION_URL`, `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES` (valeur selon V8, **commenter le pourquoi**). Rappel : pas de `revisions`/`traffic_config` (non supporté avec Agent Gateway).
4. `iam.tf` (principal agent `local.agent_principal`) :
   - `roles/aiplatform.user` (projet — 🔎 réduire si un rôle plus fin existe).
   - `roles/storage.objectUser` sur le **managed folder** uniquement (D6).
   - `roles/run.invoker` sur la **function** uniquement.
   - Service agent aiplatform : `roles/dns.peer` si DNS peering PSC-I ; rôle custom `networkservices.agentGateways.get` seulement si gateway cross-project (pas le cas ici → ne pas créer).

**Tests** : `test_tools.py` (path traversal refusé, préfixe imposé, client GCS et HTTP mockés, retry déclenché sur 503 et pas sur 403) ; `test_agent.py` (tools enregistrés, executor configuré) ; tftest (`psc_interface_config` et les deux `agent_gateway_config` présents, aucun `service_account` dans `spec` ; `override_data` + fixture d'archive comme en Phase 3).

**🛑 STOP** avant `task apply`.
**V-runtime à clore ici (après apply + Phase 6)** : **V3** (le principal dérivé de `effective_identity` est accepté par les bindings IAM), **V7** (lecture/écriture OK dans `agent-workspace/`, 403 ailleurs), **V8** (appel function authentifié via le gateway egress), **V9** (le sandbox est créé et exécute du code). Un échec → appliquer le fallback de D3/D6/D7/D8 et le consigner dans `docs/VERIFICATION.md`.
**Commit** : `feat(geap-agent-secured): deploy sandboxed adk agent behind agent gateways on the vpc`

---

### Phase 6 — `geap-agent-secured` : Registry & Agent Policy

**Mise à jour Phase 0 : tout est Terraform** (voir `docs/VERIFICATION.md`) → fichiers `registry.tf` et `policies.tf` ; les scripts `scripts/registry.sh`, `agent_policies.sh`, `semantic_gov.sh` et les tasks associées ne sont plus nécessaires. Les points ci-dessous décrivent les ressources à créer ; ignorer les mentions de scripts/gcloud.

1. **Agent Registry** (`task registry`) :
   - Service pour l'agent runtime : `--interfaces=url=https://europe-west1-aiplatform.mtls.googleapis.com/v1/projects/<num>/locations/europe-west1/reasoningEngines/<id>,protocolBinding=jsonrpc`.
   - Endpoints egress à allowlister (V13) : aiplatform régional (+ mTLS), storage, logging, telemetry, monitoring, iamcredentials, URL Cloud Run function. **Correspondance exacte de hostname** (pas de wildcard) → enregistrer les variantes régionales et mTLS.
2. **IAM agent policies** (`task agent-policies`) : `roles/iap.egressor` pour le principal de l'agent sur chaque endpoint (`--resource-type=agent-registry --endpoint=… --region=europe-west1`). Rien d'autre (default deny).
3. **Semantic governance** (`task semantic-gov`, si `ENABLE_SEMANTIC_GOVERNANCE=true`) : provisionner le policy engine (binding Google-managed sur le VPC de base), authz extension + authz policy sur `agw-egress` filtrée sur `:generateContent`/`:streamGenerateContent`, politique agent-scope en langage naturel (ex. « l'agent n'écrit que des rapports texte dans agent-workspace et n'appelle la fonction qu'avec un payload JSON de moins de 1 Ko »), **démarrage en `DRY_RUN`**.
4. Tâches `*-destroy` symétriques, appelées en `deps:` de `destroy` **avant** `terraform destroy`.

**Critères** : relancer chaque task deux fois ne produit aucune erreur ni doublon ; `gcloud … list` montre les entrées attendues.
**Commit** : `feat(geap-agent-secured): register agent and egress endpoints, add agent policies`

---

### Phase 7 — Validation E2E & sécurité

`tests/e2e/` (pytest, marqueur `e2e`, **exclu de la CI** par défaut, `task e2e` manuel) :

| Cas | Attendu |
|---|---|
| Question simple | Réponse OK |
| « Écris `hello` dans `agent-workspace/hello.txt` puis relis-le » | OK |
| « Écris dans `secret/x.txt` » | Refus (outil) ; test direct SDK avec le principal → 403 |
| « Déclenche l'action avec `{…}` » | 200 de la function, log côté function |
| « Calcule la somme des 100 premiers nombres premiers en Python » | Exécution dans le sandbox |
| Prompt injection / jailbreak connu | Bloqué par Model Armor au gateway (log Model Armor) |
| L'agent tente d'appeler une URL externe non enregistrée | Refusé par `agw-egress` (default deny) |
| Semantic governance (si activé) | Verdict `DENY` journalisé en `DRY_RUN` |

Puis : `task scan` vert, revue des logs (tous en `europe-west1`), vérification qu'aucune ressource n'est hors `europe-west1` (`gcloud asset search-all-resources --query="NOT location:europe-west1 AND NOT location:global"` en lecture seule) et lister explicitement les ressources `global` restantes (identité, IAM) dans le README.

**Commit** : `test(geap-agent-secured): add e2e security validation suite`

---

### Phase 8 — Documentation finale & déploiement CI (optionnel)

1. README de chaque sample au squelette doc-practices : Features, Architecture (Mermaid `graph TD` + `sequenceDiagram` du flux ingress → Model Armor → agent → egress gateway → GCS/function/sandbox), **Key Design Decisions** (renvoi ADR), **Security Design**, **Sovereignty** (ce qui reste global), FinOps (tableau §7 + `> [!TIP]`), Prerequisites, Deployment (`task` numérotées), Task Commands, Project Structure.
2. `TFDOCS.md` régénérés par pre-commit.
3. `deploy.yml` (si `enable_github_wif`) : `workflow_dispatch` (input sample + action plan/apply), auth WIF (`google-github-actions/auth` épinglé SHA), environment GitHub protégé (approbation manuelle pour `apply`).
4. `CHANGELOG.md` à jour, README racine à jour.

**Commit** : `docs: complete sample readmes, architecture diagrams and finops notes`

---

## 6. Registre des risques

| Risque | Probabilité | Impact | Mitigation / fallback |
|---|---|---|---|
| PSC-I + `agent_gateway_config` incompatibles sur un même engine | Moyenne | Exigence « rattaché au VPC » | Gateway egress via connectivity template **est** l'attachement VPC ; documenter et faire valider par l'utilisateur. |
| CONTENT_AUTHZ non supporté sur `CLIENT_TO_AGENT` | Moyenne | D5 | Callbacks ADK + Model Armor API régionale (`app/guardrails.py`). |
| Agent Registry / IAP egress sans Terraform | Élevée | Mécanisme | Scripts gcloud idempotents + tasks destroy symétriques. |
| Modèle par défaut indisponible en `europe-west1` régional | Moyenne | Souveraineté | Choisir le modèle le plus récent dispo en régional ; ne jamais basculer sur `global` sans accord. |
| Destroy de l'engine en erreur avec PSC-I (issue provider #25637) | Connue | DX | Documenter ; `terraform state rm` après vérification de suppression. |
| Clé KMS non supprimable | Certaine | Re-apply | `prevent_destroy`, réimport documenté (`task kms-import`). |
| Commandes `alpha`/`beta` changeantes | Élevée | Scripts cassés | Vérifier `--help` à chaque phase, épingler la version gcloud dans le README. |
| Sandbox + function tools sur le même agent | Faible | D8 | Sous-agent `coder` via `AgentTool`. |

---

## 7. FinOps (estimations à confirmer sur les pages pricing en Phase 0)

| Poste | Hypothèse | Ordre de grandeur |
|---|---|---|
| Agent Runtime ×2 | facturation vCPU-h + GiB-h ; `min_instances` bas, `max_instances ≤ 3` | quelques €/jour si une instance reste chaude ; ~0 si scale-to-zero accepté (V2) |
| Agent Gateway ×2 | 🔎 pricing GEAP | à documenter |
| Model Armor | free tier mensuel puis par million de tokens | négligeable en démo |
| Semantic governance | appel LLM par évaluation | désactivé par défaut |
| Sandbox | facturé à l'usage | négligeable en démo |
| KMS, GCS, Cloud Run function, logs | usage minimal | < 5 €/mois |
| NAT | **non provisionné** | 0 |

> [!TIP]
> Recommandation : `task destroy-all` après chaque session de démo ; `min_instances = 0` si accepté ; semantic governance en option.

---

## 8. Questions ouvertes pour l'utilisateur

1. Langue de la documentation du repo : anglais (cohérent avec `AGENT.md`) ou français ? 
Anglais
2. Projet GCP unique pour les 3 samples (hypothèse du plan) ou un projet par sample ?
Un seul projet GCP project-f574a412-a17b-41d4-893
3. Le projet est-il rattaché à une **organisation** (trust domain Agent Identity `org-…` vs `proj-…`, possibilité d'org policy `resourceLocations`) ?
Non il n'est pas rattaché a une orga
4. Déploiement depuis GitHub Actions (WIF) souhaité, ou CI limitée à lint/tests/scans ?
CI limitée à lint/tests/scans, terraform validate
5. Pipeline GitLab CI miroir (rule dev-practices) : à ajouter ou hors scope ?
hors scope