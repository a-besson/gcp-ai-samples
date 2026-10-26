# Remote state: GCS bucket created by `task bootstrap`, injected at init time (-backend-config).
terraform {
  backend "gcs" {
    prefix = "samples/geap-agent-gateway-ingress"
  }
}
