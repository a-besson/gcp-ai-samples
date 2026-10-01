# Data bucket: CMEK, private, versioned. The agent only gets the agent-workspace/ managed folder.
# Accepted KICS finding (bucket logging): legacy usage/storage logs would need a second bucket, which
# is overkill for a demo sample. Object access is NOT logged by default: enable Cloud Audit Logs
# (Data Access) for storage.googleapis.com if you need an access trail.
# kics-scan disable=d6cabc3a-d57e-48c2-b341-bf3dd4f4a120
resource "google_storage_bucket" "data" {
  name     = "${var.project_id}-geap-secured-data"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  # Sample bucket: allow `task destroy` even when the agent left objects behind
  force_destroy = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = local.base.kms_key_id
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# Managed folder = the only path the agent identity can access (IAM conditions cannot restrict listing)
resource "google_storage_managed_folder" "workspace" {
  bucket = google_storage_bucket.data.name
  name   = "agent-workspace/"
}

# Function source lives outside agent-workspace/, so the agent cannot read or alter it
data "archive_file" "function_src" {
  type        = "zip"
  source_dir  = var.function_source_dir
  output_path = "${path.module}/build/function_src.zip"
}

resource "google_storage_bucket_object" "function_src" {
  name   = "function-src/${data.archive_file.function_src.output_md5}.zip"
  bucket = google_storage_bucket.data.name
  source = data.archive_file.function_src.output_path
}
