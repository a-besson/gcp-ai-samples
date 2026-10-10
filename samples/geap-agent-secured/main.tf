# Secured GEAP agent: built on the Cloud Foundation Fabric modules
# (geap-agent-gateway, geap-agent-runtime, gcs, cloud-function-v2, iam-service-account).
#
# Every Fabric module is pinned to the same commit of the master branch (2026-10-09, see ADR 005): release
# v59.0.0 sets dns_peering_config.domain, which the google 8.5 provider rejects (fixed by commit ccd4c1c95).
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    # The Fabric GEAP modules create their resources with google-beta
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.5"
    }
    # Zips the function source (cloud-function-v2 module)
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    # Waits for IAM propagation (function build) and for the Agent Registry ingestion (semantic governance)
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

# Foundations (KMS key, VPC, registry, CMEK grants of the function service agents, ...) owned by samples/base
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
