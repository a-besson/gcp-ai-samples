# Remote state: GCS bucket created by `task bootstrap` (versioned, uniform access).
# The bucket name is injected at init time (`-backend-config`), never hardcoded.
terraform {
  backend "gcs" {
    prefix = "samples/base"
  }
}
