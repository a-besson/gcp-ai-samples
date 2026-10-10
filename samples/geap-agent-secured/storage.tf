# Data bucket: CMEK, private, versioned. The agent only gets the agent-workspace/ managed folder.
# Accepted KICS finding (bucket logging): legacy usage/storage logs would need a second bucket, which is overkill
# for a demo sample. Object access is NOT logged by default: enable Cloud Audit Logs (Data Access) for
# storage.googleapis.com if you need an access trail.
module "bucket" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id = var.project_id
  name       = "${var.project_id}-geap-secured-data"
  location   = var.region

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  encryption_key              = local.base.kms_key_id
  versioning                  = true
  # Sample bucket: allow `task destroy` even when the agent left objects behind
  force_destroy = true

  lifecycle_rules = {
    keep-3-versions = {
      action    = { type = "Delete" }
      condition = { num_newer_versions = 3 }
    }
  }

  # The only path the agent identity can access (IAM conditions cannot restrict object listing; agent identities
  # cannot hold the storage.legacyBucket* roles, so no bucket-level binding exists for them).
  managed_folders = {
    "agent-workspace/" = {
      iam = { "roles/storage.objectUser" = [local.agent_principal] }
      # The folder is deleted before the bucket: without this, `task destroy` fails once the agent wrote a file
      force_destroy = true
    }
  }
}
