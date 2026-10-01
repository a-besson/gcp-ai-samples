# Single CMEK key shared by all samples (GCS, Artifact Registry, agents, functions).
module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.2"

  project_id = var.project_id
  location   = var.region
  keyring    = "kr-${local.prefix}"
  keys       = [local.key_name]

  key_rotation_period = "7776000s" # 90 days
  prevent_destroy     = true       # a destroyed key makes all CMEK-protected data unreadable

  depends_on = [google_project_service.apis]
}

locals {
  key_name = "key-${local.prefix}"
  key_id   = module.kms.keys[local.key_name]
}

# Service agents of the services encrypting data with the key declared here.
# Agent Runtime / Cloud Functions agents are granted by the samples that use them.
data "google_storage_project_service_account" "gcs" {
  project    = var.project_id
  depends_on = [google_project_service.apis]
}

resource "google_project_service_identity" "artifact_registry" {
  provider = google-beta

  project = var.project_id
  service = "artifactregistry.googleapis.com"

  depends_on = [google_project_service.apis]
}

# Resource-level binding (on the key only), never project-wide
resource "google_kms_crypto_key_iam_member" "cmek_users" {
  for_each = {
    storage           = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
    artifact_registry = "serviceAccount:${google_project_service_identity.artifact_registry.email}"
  }

  crypto_key_id = local.key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}
