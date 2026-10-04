# Secured GEAP agent: Agent Runtime behind two Agent Gateways (Model Armor on ingress, default-deny
# egress), attached to the Belgium VPC, scoped bucket access, Cloud Run function, sandboxed code.
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    # Only for google_project_service_identity (service agents)
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    # Waits for the Agent Registry to ingest the deployed agent and for new service agents
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
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

# Foundations (KMS key, VPC, registry, ...) owned by samples/base
data "terraform_remote_state" "base" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "samples/base"
  }
}

locals {
  labels = {
    project    = "gcp-samples_geap-agent-secured"
    env        = var.env
    managed-by = "terraform"
  }

  agent_name = "geap-agent-secured"

  base = data.terraform_remote_state.base.outputs

  # Registry location used by the gateways and the registered endpoints
  registry = "//agentregistry.googleapis.com/projects/${var.project_id}/locations/${var.region}"
}
