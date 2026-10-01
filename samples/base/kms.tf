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

# Service agents of the services encrypting data with the key. They are owned here, with the key,
# so that the samples never share an IAM binding. Function/Run agents are owned by geap-agent-secured.
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

resource "google_project_service_identity" "aiplatform" {
  provider = google-beta

  project = var.project_id
  service = "aiplatform.googleapis.com"

  depends_on = [google_project_service.apis]
}

# A freshly created service agent is not immediately known to IAM ("Service account ... does not
# exist"): wait before binding it to the key.
resource "time_sleep" "service_agents" {
  create_duration = "30s"

  depends_on = [
    data.google_storage_project_service_account.gcs,
    google_project_service_identity.artifact_registry,
    google_project_service_identity.aiplatform,
  ]
}

locals {
  cmek_users = merge(
    {
      storage           = data.google_storage_project_service_account.gcs.email_address
      artifact_registry = google_project_service_identity.artifact_registry.email
      aiplatform        = google_project_service_identity.aiplatform.email
    },
    { for index, email in var.extra_cmek_service_agents : "extra_${index}" => email },
  )
}

# Resource-level binding (on the key only), never project-wide
resource "google_kms_crypto_key_iam_member" "cmek_users" {
  for_each = local.cmek_users

  crypto_key_id = local.key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.value}"

  depends_on = [time_sleep.service_agents]
}
