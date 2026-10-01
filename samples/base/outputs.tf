output "region" {
  description = "Region of all regional resources (Belgium)."
  value       = var.region
}

output "project_number" {
  description = "Project number, used to build Agent Identity principals and service agent emails."
  value       = data.google_project.this.number
}

output "kms_key_id" {
  description = "ID of the single CMEK key shared by all samples."
  value       = local.key_id
}

output "kms_keyring_id" {
  description = "ID of the key ring holding the shared key."
  value       = module.kms.keyring
}

output "network_id" {
  description = "ID of the VPC shared by all samples."
  value       = module.vpc.network_id
}

output "network_name" {
  description = "Name of the shared VPC."
  value       = module.vpc.network_name
}

output "subnet_workloads_id" {
  description = "ID of the workloads subnet."
  value       = module.vpc.subnets["${var.region}/snet-workloads-ew1"].id
}

output "subnet_psc_attach_id" {
  description = "ID of the subnet reserved for PSC interface network attachments."
  value       = module.vpc.subnets["${var.region}/snet-psc-attach-ew1"].id
}

output "artifact_registry_repository" {
  description = "Name of the CMEK-protected Docker repository (Cloud Functions builds)."
  value       = google_artifact_registry_repository.docker.name
}

output "artifact_registry_repository_id" {
  description = "Repository ID of the Docker repository."
  value       = google_artifact_registry_repository.docker.repository_id
}

output "log_bucket_id" {
  description = "ID of the regional log bucket."
  value       = google_logging_project_bucket_config.regional.id
}
