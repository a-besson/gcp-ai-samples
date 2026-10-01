# geap-agent-simple

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 8.5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 8.5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_vertex_ai_reasoning_engine.agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vertex_ai_reasoning_engine) | resource |
| [terraform_remote_state.base](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_source_archive"></a> [agent\_source\_archive](#input\_agent\_source\_archive) | Path to the agent source tar.gz built by `task package` (main file at the archive root). | `string` | `"build/agent_src.tar.gz"` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment label applied to every resource. | `string` | `"sandbox"` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum instances, bounded to protect the budget. | `number` | `2` | no |
| <a name="input_min_instances"></a> [min\_instances](#input\_min\_instances) | Minimum warm instances (0 = scale to zero, cheapest). | `number` | `0` | no |
| <a name="input_model"></a> [model](#input\_model) | Gemini model name served by the regional europe-west1 endpoint. Check availability before changing it. | `string` | `"gemini-3.5-flash"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID hosting the samples (from GCP\_PROJECT\_ID in .env). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the agent and of the model endpoint. Locked to Belgium for data sovereignty. | `string` | `"europe-west1"` | no |
| <a name="input_state_bucket"></a> [state\_bucket](#input\_state\_bucket) | GCS bucket holding the Terraform state of samples/base (TF\_STATE\_BUCKET in .env). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_principal"></a> [agent\_principal](#output\_agent\_principal) | IAM principal of the agent (Agent Identity). |
| <a name="output_reasoning_engine_id"></a> [reasoning\_engine\_id](#output\_reasoning\_engine\_id) | Full resource name of the deployed Agent Runtime engine. |
<!-- END_TF_DOCS -->
