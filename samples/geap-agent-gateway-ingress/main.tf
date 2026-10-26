# GEAP agent behind an ingress Agent Gateway: ADK agent answering with Claude Haiku on Vertex AI, client prompts
# screened by Model Armor before they reach the agent. Built on the Cloud Foundation Fabric modules
# (geap-agent-gateway, geap-agent-runtime), pinned to the same commit as geap-agent-secured (see ADR 005).
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.5.0"
    }
    # The Fabric GEAP modules create their resources with google-beta
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "8.5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id

  default_labels = local.labels
}

provider "google-beta" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id

  default_labels = local.labels
}

# Foundations (KMS key, project number, regional log bucket) owned by samples/base
data "terraform_remote_state" "base" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "samples/base"
  }
}

locals {
  labels = {
    project    = "gcp-samples_geap-agent-gateway-ingress"
    env        = var.env
    managed-by = "terraform"
  }

  agent_name = "geap-agent-gateway-ingress"

  base = data.terraform_remote_state.base.outputs

  # Registry location governed by the gateway (Agent Runtime engines register there)
  registry = "//agentregistry.googleapis.com/projects/${var.project_id}/locations/${var.region}"
}
