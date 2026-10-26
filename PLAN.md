# PLAN — Sample `geap-agent-gateway-ingress`

> **Avancement (2026-10-25)** — Phases 1 à 3 exécutées. Hors ligne : 25 pytest, 12 tftest, pre-commit et KICS
> verts ; Trivy vert sur ce sample (4 vulnérabilités `aiohttp` / `certifi` préexistantes dans les verrous de
> `geap-agent-simple` et `geap-agent-secured`, hors périmètre). Déployé dans le nouveau projet (bucket de state recréé en `europe-west1`, `base` appliqué, 10
> ressources pour le sample), puis inférence basculée sur le multi-région `eu`. E2E **10/11** : tous les contrôles Model Armor, de contournement et le contrôle positif des
> sessions passent ; seule la réponse de Claude échoue sur le **quota Claude Haiku 5.5 à 0** (`429`), les demandes d'augmentation par API ayant été refusées
> automatiquement. Repli **temporaire** sur `gemini-3.8-flash` (multi-région `eu`, `TF_VAR_model=gemini-3.8-flash`, Claude reste le
> défaut) : E2E **11/11**. Résultats détaillés : README du sample (« Validation at deployment »).

> Rédigé le 2026-10-25 à partir de `PROMPT.md` (gitignoré), des samples `geap-agent-simple` /
> `geap-agent-secured`, de l'historique `docs/VERIFICATION.md` (git) et de la documentation GEAP
> (Agent Gateway, intégration Model Armor, codelab « Agent Gateway ingress to Agent Runtime with
> Model Armor »). Tout ce qui est marqué 🔎 n'est **pas confirmé** et doit être vérifié au premier
> déploiement, puis consigné dans le README du sample.

---

## 1. Prompt amélioré

**Rôle** : Cloud Architect / DevSecOps, conventions du repo `gcp-ia-samples` (`AGENTS.md`).

**Objectif** : ajouter un sample `samples/geap-agent-gateway-ingress` qui déploie sur Gemini
Enterprise Agent Platform (GEAP) :

1. un agent **ADK** sur **Agent Runtime** (Agent Identity, CMEK de `samples/base`, `europe-west1`)
   qui répond aux questions avec **Claude Haiku 5.5** (`claude-haiku-5-5`, partner model Vertex AI),
   **inférence dans l'UE uniquement** (`model_location` validé, défaut choisi après sonde) ;
2. une **Agent Gateway `CLIENT_TO_AGENT`** (ingress) reliée à l'engine, avec **Model Armor** activé
   (`CONTENT_AUTHZ`, fail closed) pour bloquer les **prompt injections / jailbreaks** avant qu'ils
   n'atteignent l'agent, et filtrer ses réponses ;
3. une suite **E2E** qui prouve que **c'est bien Model Armor, à la gateway**, qui bloque — et non le
   modèle qui refuse de lui-même.

**Contraintes** :

- Réutiliser les conventions des samples existants : Terraform par domaine, modules **Cloud
  Foundation Fabric** épinglés au même SHA que `geap-agent-secured` (ADR 005), providers `google` /
  `google-beta` `8.5.0`, `default_labels` avec `project = gcp-samples_geap-agent-gateway-ingress`,
  `validation {}` sur les variables, Taskfile v3, tests hors ligne (pytest + `terraform test` avec
  providers mockés), CI `build-<sample>`, README / TFDOCS / CHANGELOG.
- Aucun secret, project ID ou numéro de projet dans le code, la doc ou les logs (placeholders
  `my-gcp-project-id`, `123456789012`).
- Ne jamais affaiblir un contrôle qualité / sécurité pour le faire passer.

**Livrables** : agent déployé et fonctionnel, E2E verts contre le déploiement, sample conforme
aux conventions (pre-commit, KICS, Trivy, tests hors ligne verts).

---

## 2. Contexte hérité (faits établis dans le repo)

| Fait | Source | Conséquence |
|---|---|---|
| Quota `RegionalAgentGateways` = 2 en `europe-west1` | VERIFICATION (2026-10-09) | Ce sample (1 gateway) ne coexiste pas avec `geap-agent-secured` (2 gateways). Hors de `apply-all`. |
| `psc_interface_config` et `agent_gateway_config` incompatibles sur un engine | VERIFICATION (2026-10-01) | Pas de PSC-I ; inutile ici (pas d'accès VPC). |
| Point d'entrée = `AdkApp`, pas un `LlmAgent` brut | VERIFICATION | Idem samples existants. |
| `google-beta` 8.6 perd un `client_to_agent_config` dont l'id n'est connu qu'après apply | VERIFICATION (2026-10-10) | Id de gateway construit depuis son nom. |
| Le module gateway Fabric configure son propre provider | ADR 005 | `override_module` dans `terraform test`, labels passés explicitement. |
| Sous Agent Identity, les tokens sont **liés au certificat** (mTLS) par défaut | `google/auth/_agent_identity_utils.py` | Le SDK `anthropic` (httpx, hôte non mTLS) ne présente pas le certificat → `GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=false` (option `--allow-token-sharing` du codelab). Compromis documenté. |
| L'hôte mTLS du multi-région `eu` n'existe pas | VERIFICATION (2026-10-04) | Sans objet ici (tokens non liés), `eu` redevient admissible pour ce sample. |
| Model Armor n'inspecte en ingress **que** `reasoningEngines.streamQuery` des agents ADK | Doc intégration Model Armor | Seule `async_stream_query` est exposée par l'agent ; toute autre méthode serait un contournement. |
| Le service agent `gcp-sa-aiplatform-re` doit avoir `roles/modelarmor.calloutUser` + `roles/modelarmor.user` | Doc intégration Model Armor | Grants absents de `geap-agent-secured` : ajoutés ici. |
| L'E2E Model Armor de `geap-agent-secured` passe même si Model Armor est inactif (`"PWNED" not in answer`) | `tests/e2e/test_e2e.py` | Ne pas le copier : prouver le blocage côté gateway. |

---

## 3. Décisions d'architecture

| # | Décision | Justification | Alternative rejetée |
|---|---|---|---|
| D1 | **Une seule gateway** `CLIENT_TO_AGENT` (module Fabric `geap-agent-gateway`, `iap_config = null`, `model_armor_config`), engine lié en ingress uniquement | Besoin exprimé = ingress ; une gateway de moins (coût fixe, quota) ; sortie directe comme `geap-agent-simple` | Ajouter l'egress (hors périmètre, allowlist à maintenir) |
| D2 | **Claude via `google.adk.models.anthropic_llm.Claude`** avec un client `AsyncAnthropicVertex` explicite (`region = MODEL_LOCATION`, `max_retries`) | Région du modèle indépendante de `GOOGLE_CLOUD_LOCATION` (région de l'engine : sessions, télémétrie), comme `client_kwargs` côté Gemini | LiteLLM (dépendance lourde, même problème de token) |
| D3 | **Tokens Agent Identity non liés** (`GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=false`) | Le SDK `anthropic` n'utilise pas mTLS ; valeur de la doc gateway / codelab | Client httpx mTLS maison avec le certificat de l'agent : plus sûr mais non documenté, impossible avec `eu` |
| D4 | **Model Armor fail closed**, templates `INSPECT_AND_BLOCK` explicites, PI/jailbreak `MEDIUM_AND_ABOVE`, `log_sanitize_operations = true` | Blocage vérifiable et traçable ; une panne Model Armor refuse au lieu de laisser passer. Les messages d'erreur personnalisés des templates, essayés comme sentinelle, ne sont pas relayés par la gateway (retirés) | Fail open (codelab) : contournable par indisponibilité |
| D5 | **Surface réduite** : `AdkApp` sous-classée, seule `async_stream_query` enregistrée | `stream_query` / `streaming_agent_run_with_events` ne sont pas garanties inspectées → contournement possible | Garder toutes les méthodes d'`AdkApp` |
| D6 | **Grants Model Armor** du service agent `gcp-sa-aiplatform-re` portés par ce sample (`iam.tf`), après création de l'engine (le service agent naît avec le premier engine) | Doc officielle ; aucun autre sample ne les détient | Les mettre dans `base` (inutile aux autres samples) |
| D7 | **Modèle et région** : variable `model` (`claude-haiku-5-5`, regex `^claude-…(@date)?$`), `model_location` ∈ régions UE + `eu`, défaut **`eu`** (multi-région UE, demande utilisateur du 2026-10-25) | Souveraineté : traitement ML dans l'UE, capacité répartie sur les régions UE | `global` (pas de résidence des données) ; `europe-west1` (défaut initial, remplacé) |
| D8 | Versions Python alignées sur les samples (`google-adk 2.10.0`, `google-cloud-aiplatform 2.3.0`) + `anthropic[vertex] 1.12.1` (dernière 1.x ≥ 2 semaines ; 2.x sortie le 2026-10-21, postérieure à ADK 2.10) | Stack déjà prouvée sur Agent Runtime ; compatibilité vérifiée par test hors ligne | ADK 2.13 / anthropic 2.x (non testés avec le reste du repo) |

---

## 4. Arborescence cible

```text
samples/geap-agent-gateway-ingress/
├── app/                  # racine de l'archive : agent.py, config.py, logger.py, requirements.txt
├── scripts/              # package.py, invoke.py, check_model.py (sonde du modèle Claude)
├── tests/                # test_agent.py, conftest.py, ingress.tftest.hcl, fixtures/, e2e/
├── main.tf  backend.tf  variables.tf  outputs.tf
├── model_armor.tf        # templates request / response
├── gateway.tf            # module geap-agent-gateway (CLIENT_TO_AGENT + Model Armor)
├── agent.tf              # module geap-agent-runtime (ingress uniquement)
├── iam.tf                # rôles Model Armor du service agent Agent Runtime
├── requirements.in  requirements-dev.txt  pyproject.toml  .env.example
├── README.md  TFDOCS.md
└── Taskfile.yml
```

Fichiers racine touchés : `Taskfile.yml` (include `ingress`, `test-all`, `destroy-all`),
`README.md` (table, arbre), `kics.config` (exclusions `.venv`/`.terraform`/`build`),
`.github/workflows/build-geap-agent-gateway-ingress.yml`, `CHANGELOG.md` (entrée du 2026-10-25),
`docs/adr/006-claude-on-agent-runtime-behind-ingress-gateway.md`.

---

## 5. Stratégie E2E (`task e2e`, hors CI, facturable)

Objectif : distinguer « Model Armor a bloqué à la gateway » de « Claude a refusé ».

| Test | Preuve | Déterministe |
|---|---|---|
| `test_benign_prompt_reaches_the_agent` | Une session existe pour ce `user_id` unique, quel que soit le résultat du modèle : la policy fail closed et les IAM laissent passer le trafic légitime, et la recherche de sessions dont dépendent les tests de blocage fonctionne (contrôle positif). | Oui |
| `test_benign_prompt_is_answered_by_claude` | Question simple → « Brussels ». | Oui (assertion lâche sur le texte) |
| `test_template_flags_injection[...]` | `sanitizeUserPrompt` direct sur le template request (endpoint régional) → `MATCH_FOUND` sur PI/jailbreak. Valide le classifieur indépendamment du câblage. | Oui, sans LLM |
| `test_injection_is_blocked_at_the_gateway[...]` | Via l'agent, `user_id` unique : (a) `403 PERMISSION_DENIED` « Model Armor: Prompt violates content security configurations » renvoyé par la gateway ; (b) **aucune session** pour ce `user_id` (l'agent n'a jamais vu la requête). | Oui, sans LLM |
| `test_block_is_logged_by_model_armor` | Journal `sanitize_operations` (bucket régional de `base`) : verdict `BLOCK` du template request pour ce prompt précis (texte base64 décodé), interrogé par polling. | Oui (latence de logs bornée) |
| `test_unscreened_methods_are_not_exposed` | `streaming_agent_run_with_events` / `stream_query` refusées par l'API (`404`). | Oui |

✅ Forme de la réponse bloquée observée le 2026-10-25 : HTTP `403 PERMISSION_DENIED`, message « Model Armor:
Prompt violates content security configurations », figée dans le test et le README.

---

## 6. Phases

### Phase 1 — Code et tests hors ligne

1. Sample complet (§4), conventions de `geap-agent-secured` (Fabric, override_module, override_data,
   fixture d'archive).
2. `task setup && task test` : pytest (config, construction de l'agent Claude, méthodes exposées,
   callbacks de log) + `terraform test` (Agent Identity, CMEK, liaison ingress seule, pas d'egress,
   pas de PSC-I, Model Armor fail closed et `INSPECT_AND_BLOCK`, grants du service agent, région,
   localisation UE du modèle, labels).
3. Intégration racine (§4), ADR 006, README, CHANGELOG.
4. `pre-commit run --all-files`, `task scan` (KICS + Trivy).

**Critère** : tout est vert sans credentials.

### Phase 2 — Accès et sonde 🛑

1. Prérequis utilisateur : `.env` pointant vers un projet accessible (ADC), `task bootstrap` et
   `task base:apply` faits ; `geap-agent-secured` non déployé (quota).
2. `task ingress:check-model` : appel `rawPredict` minimal (quelques tokens) de `claude-haiku-5-5` sur
   `europe-west1`, puis `eu` si besoin 🔎 (activation Model Garden / conditions Anthropic, quota
   régional à 0, suffixe `@version`).
3. Fixer le défaut de `model_location` d'après la sonde.

### Phase 3 — Déploiement et E2E

1. `task ingress:apply` (accord FinOps donné le 2026-10-25).
2. `task ingress:invoke -- "What is the capital of Belgium?"`.
3. `task ingress:e2e` ; ajuster la sentinelle / le format de blocage observé ; consigner les
   résultats (durées, comportement) dans le README (« Validation at deployment »).

**Critère** : E2E verts contre l'agent déployé ; pre-commit vert ; documentation à jour.

---

## 7. Risques et points ouverts

| Risque | Mitigation |
|---|---|
| ✅ `claude-haiku-5-5` servi en `europe-west1`, `europe-west4`, `europe-north1`, `eu` ; **quota 0** partout, demandes API refusées | Demande par la console / le support (action utilisateur) |
| ✅ Modèle reconnu par l'API (`429` quota et non `403` / `404`) | — |
| ✅ Grants du service agent Agent Runtime suffisants : le prompt bénin passe la gateway fail closed | Pas de grant `gcp-sa-dep` |
| ✅ Override de `register_operations` respecté (`404` sur les autres méthodes) | — |
| Propagation IAM / sessions juste après l'apply | Retry borné (tenacity) sur le test bénin |
| Coût fixe de la gateway | README FinOps, `task destroy` après démo |
