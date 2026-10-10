# geap-agent-secured

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.7 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 8.5 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 8.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 8.6.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.2 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_agent"></a> [agent](#module\_agent) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-runtime | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_bucket"></a> [bucket](#module\_bucket) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_function"></a> [function](#module\_function) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-function-v2 | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_function_build_sa"></a> [function\_build\_sa](#module\_function\_build\_sa) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_gateway_egress"></a> [gateway\_egress](#module\_gateway\_egress) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_gateway_ingress"></a> [gateway\_ingress](#module\_gateway\_ingress) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway | 25d8d9a0ca869fd15083a16183f61de1408524e3 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_agent_registry_service.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/agent_registry_service) | resource |
| [google_compute_network_attachment.gateway_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_attachment) | resource |
| [google_iap_agent_registry_endpoint_iam_member.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_agent_registry_endpoint_iam_member) | resource |
| [google_model_armor_template.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/model_armor_template) | resource |
| [google_vertex_ai_semantic_governance_policy.agent_scope](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vertex_ai_semantic_governance_policy) | resource |
| [google_vertex_ai_semantic_governance_policy_engine.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vertex_ai_semantic_governance_policy_engine) | resource |
| [time_sleep.agent_ingestion](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.function_build_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_agent_registry_agent.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/agent_registry_agent) | data source |
| [terraform_remote_state.base](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_source_archive"></a> [agent\_source\_archive](#input\_agent\_source\_archive) | Path to the agent source tar.gz built by `task package` (main file at the archive root). | `string` | `"build/agent_src.tar.gz"` | no |
| <a name="input_enable_semantic_governance"></a> [enable\_semantic\_governance](#input\_enable\_semantic\_governance) | Provision the semantic governance policy engine and an agent-scope policy (Preview, billed per LLM evaluation). | `bool` | `false` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment label applied to every resource. | `string` | `"sandbox"` | no |
| <a name="input_function_source_dir"></a> [function\_source\_dir](#input\_function\_source\_dir) | Directory holding the Cloud Run function source (main.py, requirements.txt). | `string` | `"function_src"` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum instances, bounded to protect the budget. | `number` | `2` | no |
| <a name="input_min_instances"></a> [min\_instances](#input\_min\_instances) | Minimum warm instances (0 = scale to zero, cheapest). | `number` | `0` | no |
| <a name="input_model"></a> [model](#input\_model) | Gemini model name, served by the regional endpoint of model\_location. Check availability before changing it (europe-west1 serves gemini-2.5-* only). | `string` | `"gemini-3.5-flash"` | no |
| <a name="input_model_location"></a> [model\_location](#input\_model\_location) | EU region whose regional endpoint serves the model. Inference stays in the EU; the resources stay in var.region. | `string` | `"europe-west3"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID hosting the samples (from GCP\_PROJECT\_ID in .env). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of every resource (agent engine, gateways, bucket, function). Locked to Belgium for data sovereignty. | `string` | `"europe-west1"` | no |
| <a name="input_semantic_policy"></a> [semantic\_policy](#input\_semantic\_policy) | Natural-language constraint enforced by the semantic governance policy (only used when enable\_semantic\_governance is true). | `string` | `"The agent only writes plain-text reports under agent-workspace/ and only calls the backend function with a small JSON payload."` | no |
| <a name="input_state_bucket"></a> [state\_bucket](#input\_state\_bucket) | GCS bucket holding the Terraform state of samples/base (TF\_STATE\_BUCKET in .env). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_principal"></a> [agent\_principal](#output\_agent\_principal) | IAM principal of the agent (Agent Identity). |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Data bucket; the agent only reaches the agent-workspace/ managed folder. |
| <a name="output_connectivity_template_id"></a> [connectivity\_template\_id](#output\_connectivity\_template\_id) | Agent connectivity template of the egress gateway (project-number form). |
| <a name="output_egress_allowlist"></a> [egress\_allowlist](#output\_egress\_allowlist) | Endpoints the agent identity is allowed to reach through the egress gateway. |
| <a name="output_function_url"></a> [function\_url](#output\_function\_url) | Internal-only URL of the backend Cloud Run function. |
| <a name="output_gateway_egress_id"></a> [gateway\_egress\_id](#output\_gateway\_egress\_id) | ID of the AGENT\_TO\_ANYWHERE Agent Gateway (default deny). |
| <a name="output_gateway_ingress_id"></a> [gateway\_ingress\_id](#output\_gateway\_ingress\_id) | ID of the CLIENT\_TO\_AGENT Agent Gateway (Model Armor). |
| <a name="output_reasoning_engine_id"></a> [reasoning\_engine\_id](#output\_reasoning\_engine\_id) | Full resource name of the deployed Agent Runtime engine. |
<!-- END_TF_DOCS -->
