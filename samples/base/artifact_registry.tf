# Docker repository (CMEK) in Belgium, used by Cloud Functions builds.
resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "ar-${local.prefix}"
  format        = "DOCKER"
  description   = "Container images for the GEAP samples"
  kms_key_name  = local.key_id

  docker_config {
    immutable_tags = true
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  depends_on = [
    google_project_service.apis,
    google_kms_crypto_key_iam_member.cmek_users,
  ]
}
