# geap-agent-gateway-ingress

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 8.5.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 8.5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 8.5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_agent"></a> [agent](#module\_agent) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-runtime | 25d8d9a0ca869fd15083a16183f61de1408524e3 |
| <a name="module_gateway_ingress"></a> [gateway\_ingress](#module\_gateway\_ingress) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway | 25d8d9a0ca869fd15083a16183f61de1408524e3 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_model_armor_template.this](https://registry.terraform.io/providers/hashicorp/google/8.5.0/docs/resources/model_armor_template) | resource |
| [google_project_iam_member.model_armor_callout](https://registry.terraform.io/providers/hashicorp/google/8.5.0/docs/resources/project_iam_member) | resource |
| [terraform_remote_state.base](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_source_archive"></a> [agent\_source\_archive](#input\_agent\_source\_archive) | Path to the agent source tar.gz built by `task package` (main file at the archive root). | `string` | `"build/agent_src.tar.gz"` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment label applied to every resource. | `string` | `"sandbox"` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum instances, bounded to protect the budget. | `number` | `2` | no |
| <a name="input_min_instances"></a> [min\_instances](#input\_min\_instances) | Minimum warm instances (0 = scale to zero, cheapest). | `number` | `0` | no |
| <a name="input_model"></a> [model](#input\_model) | Claude model served by Vertex AI in model\_location (partner model, enabled in Model Garden), or a Gemini model as a temporary fallback while Claude has no quota. Check it with `task check-model` before changing it. | `string` | `"claude-haiku-5-5"` | no |
| <a name="input_model_location"></a> [model\_location](#input\_model\_location) | EU location whose Vertex AI endpoint serves the model: the eu multi-region (default) or an EU member-state region. Inference stays in the EU; the resources stay in var.region. | `string` | `"eu"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID hosting the samples (from GCP\_PROJECT\_ID in .env). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of every resource (agent engine, gateway, Model Armor templates). Locked to Belgium for data sovereignty. | `string` | `"europe-west1"` | no |
| <a name="input_state_bucket"></a> [state\_bucket](#input\_state\_bucket) | GCS bucket holding the Terraform state of samples/base (TF\_STATE\_BUCKET in .env). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_principal"></a> [agent\_principal](#output\_agent\_principal) | IAM principal of the agent (Agent Identity). |
| <a name="output_gateway_ingress_id"></a> [gateway\_ingress\_id](#output\_gateway\_ingress\_id) | ID of the CLIENT\_TO\_AGENT Agent Gateway (Model Armor). |
| <a name="output_log_view"></a> [log\_view](#output\_log\_view) | Log view of the regional bucket of samples/base, holding the Model Armor sanitization logs (read by `task e2e`). |
| <a name="output_reasoning_engine_id"></a> [reasoning\_engine\_id](#output\_reasoning\_engine\_id) | Full resource name of the deployed Agent Runtime engine. |
| <a name="output_request_template_id"></a> [request\_template\_id](#output\_request\_template\_id) | Model Armor template screening the client prompts. |
| <a name="output_response_template_id"></a> [response\_template\_id](#output\_response\_template\_id) | Model Armor template screening the agent answers. |
<!-- END_TF_DOCS -->
