# Backend function the agent can trigger. Dedicated service accounts, internal-only ingress.
resource "google_service_account" "function_runtime" {
  account_id   = "sa-fn-agent-action"
  display_name = "Runtime identity of fn-agent-action (no role: it calls nothing)"
}

resource "google_service_account" "function_build" {
  account_id   = "sa-fn-agent-build"
  display_name = "Build identity of fn-agent-action"
}

# Required by Cloud Build to build and push the function image with a user-specified service account
resource "google_project_iam_member" "function_build" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.function_build.email}"
}

# Service agents encrypting the function with the shared key. They are granted here (not in samples/base)
# because only this sample deploys a function.
resource "google_project_service_identity" "function_agents" {
  provider = google-beta
  for_each = toset(["cloudfunctions.googleapis.com", "run.googleapis.com"])

  project = var.project_id
  service = each.value
}

# A freshly created service agent is not immediately known to IAM: wait before binding it
resource "time_sleep" "function_agents" {
  create_duration = "30s"
  depends_on      = [google_project_service_identity.function_agents]
}

resource "google_kms_crypto_key_iam_member" "function_agents" {
  for_each = google_project_service_identity.function_agents

  crypto_key_id = local.base.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.value.email}"

  depends_on = [time_sleep.function_agents]
}

resource "google_cloudfunctions2_function" "action" {
  name        = "fn-agent-action"
  location    = var.region
  description = "Acknowledges JSON payloads sent by the secured agent"

  kms_key_name = local.base.kms_key_id

  build_config {
    runtime           = "python313"
    entry_point       = "handle"
    docker_repository = local.base.artifact_registry_repository
    service_account   = google_service_account.function_build.id

    source {
      storage_source {
        bucket = google_storage_bucket.data.name
        object = google_storage_bucket_object.function_src.name
      }
    }
  }

  service_config {
    service_account_email          = google_service_account.function_runtime.email
    min_instance_count             = 0
    max_instance_count             = 1
    available_memory               = "256M"
    timeout_seconds                = 30
    all_traffic_on_latest_revision = true
    # Reachable only from inside the VPC / Google network: never from the internet
    ingress_settings = "ALLOW_INTERNAL_ONLY"
  }

  depends_on = [
    google_project_iam_member.function_build,
    google_kms_crypto_key_iam_member.function_agents,
  ]
}
