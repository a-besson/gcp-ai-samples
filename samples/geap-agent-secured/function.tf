# Backend function the agent can trigger. Dedicated service accounts, internal-only ingress.
# The CMEK grants of the Cloud Functions and Cloud Run service agents are owned by samples/base, next to the key:
# two samples binding the same member would remove it from each other on destroy.

module "function_build_sa" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id   = var.project_id
  name         = "sa-fn-agent-build"
  display_name = "Build identity of fn-agent-action"
  # Required by Cloud Build to build and push the function image with a user-specified service account
  iam_project_roles = {
    (var.project_id) = ["roles/cloudbuild.builds.builder"]
  }
}

module "function" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-function-v2?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id  = var.project_id
  region      = var.region
  name        = "fn-agent-action"
  description = "Acknowledges JSON payloads sent by the secured agent"

  # Source zipped and uploaded to the data bucket, outside agent-workspace/: the agent cannot read or alter it
  bucket_name = module.bucket.name
  bundle_config = {
    path = var.function_source_dir
    folder_options = {
      archive_path = "${path.module}/build/function_src.zip"
    }
  }

  kms_key = local.base.kms_key_id
  # Full path expected by Cloud Functions; the repository is CMEK-protected with the same key (module requirement)
  docker_repository_id  = "projects/${var.project_id}/locations/${var.region}/repositories/${local.base.artifact_registry_repository_id}"
  build_service_account = module.function_build_sa.id

  function_config = {
    entry_point        = "handle"
    runtime            = "python313"
    instance_count     = 1
    min_instance_count = 0
    memory_mb          = 256
    timeout_seconds    = 30
  }
  # Reachable only from inside the VPC / Google network: never from the internet
  ingress_settings = "ALLOW_INTERNAL_ONLY"

  # Runtime identity with no role: the function calls nothing
  service_account_config = {
    name         = "sa-fn-agent-action"
    display_name = "Runtime identity of fn-agent-action (no role: it calls nothing)"
    roles        = []
  }

  # The agent may invoke this function, and nothing else
  iam = {
    "roles/run.invoker" = [local.agent_principal]
  }

  # The build service account needs its Cloud Build role before the first build
  depends_on = [time_sleep.function_build_iam]
}

# A new IAM grant takes up to a minute to propagate: building right after it fails with
# "Access to bucket gcf-v2-sources-... denied" (observed on the first apply, 2026-10-09).
resource "time_sleep" "function_build_iam" {
  create_duration = "60s"
  depends_on      = [module.function_build_sa]
}
