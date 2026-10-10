# base

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 8.5 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 8.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 8.5.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 8.5.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.2 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_kms"></a> [kms](#module\_kms) | terraform-google-modules/kms/google | ~> 4.2 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-google-modules/network/google | ~> 18.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_project_service_identity.aiplatform](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google-beta_google_project_service_identity.artifact_registry](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google-beta_google_project_service_identity.functions](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_artifact_registry_repository.docker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_billing_budget.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |
| [google_compute_global_address.psc_google_apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.psc_google_apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_dns_managed_zone.run_app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.run_app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_kms_crypto_key_iam_member.cmek_users](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_logging_project_bucket_config.regional](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_bucket_config) | resource |
| [google_logging_project_exclusion.default_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_exclusion) | resource |
| [google_logging_project_sink.regional](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [time_sleep.service_agents](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | Billing account ID (XXXXXX-XXXXXX-XXXXXX) for the budget alerts. Null or empty: use the billing account linked to the project when readable, otherwise no budget. | `string` | `null` | no |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget amount (in budget\_currency) triggering the 50/90/100 % alerts. Bounded to protect the bill. | `number` | `50` | no |
| <a name="input_budget_currency"></a> [budget\_currency](#input\_budget\_currency) | ISO 4217 currency of the budget; must match the billing account currency. | `string` | `"EUR"` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment label applied to every resource. | `string` | `"sandbox"` | no |
| <a name="input_extra_cmek_service_agents"></a> [extra\_cmek\_service\_agents](#input\_extra\_cmek\_service\_agents) | Additional service agent emails granted on the shared key, e.g. the Agent Runtime agent service-<PROJECT\_NUMBER>@gcp-sa-aiplatform-re.iam.gserviceaccount.com if the agent engine CMEK needs it. | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the regional (europe-west1) log bucket, in days. | `number` | `30` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID hosting all samples (from GCP\_PROJECT\_ID in .env). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of every regional resource. Locked to Belgium for data sovereignty. | `string` | `"europe-west1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_artifact_registry_repository"></a> [artifact\_registry\_repository](#output\_artifact\_registry\_repository) | Full resource path (projects/<p>/locations/<l>/repositories/<r>) of the CMEK-protected Docker repository, as expected by Cloud Functions builds. |
| <a name="output_artifact_registry_repository_id"></a> [artifact\_registry\_repository\_id](#output\_artifact\_registry\_repository\_id) | Repository ID of the Docker repository. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | ID of the single CMEK key shared by all samples. |
| <a name="output_kms_keyring_id"></a> [kms\_keyring\_id](#output\_kms\_keyring\_id) | ID of the key ring holding the shared key. |
| <a name="output_log_bucket_id"></a> [log\_bucket\_id](#output\_log\_bucket\_id) | ID of the regional log bucket. |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | ID of the VPC shared by all samples. |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Name of the shared VPC. |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | Project number, used to build Agent Identity principals and service agent emails. |
| <a name="output_region"></a> [region](#output\_region) | Region of all regional resources (Belgium). |
| <a name="output_run_app_private_dns_name"></a> [run\_app\_private\_dns\_name](#output\_run\_app\_private\_dns\_name) | DNS name of the private zone sending *.run.app to the PSC endpoint for Google APIs (for Agent Gateway DNS peering). |
| <a name="output_subnet_psc_attach_id"></a> [subnet\_psc\_attach\_id](#output\_subnet\_psc\_attach\_id) | ID of the subnet reserved for PSC interface network attachments. |
| <a name="output_subnet_workloads_id"></a> [subnet\_workloads\_id](#output\_subnet\_workloads\_id) | ID of the workloads subnet. |
<!-- END_TF_DOCS -->
