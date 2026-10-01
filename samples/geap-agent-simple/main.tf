# Simple GEAP agent: ADK agent on Agent Runtime answering a question through an LLM.
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
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

# Foundations (KMS key, VPC, ...) owned by samples/base
data "terraform_remote_state" "base" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "samples/base"
  }
}

locals {
  labels = {
    project    = "gcp-samples_geap-agent-simple"
    env        = var.env
    managed-by = "terraform"
  }

  agent_name = "geap-agent-simple"
  kms_key_id = data.terraform_remote_state.base.outputs.kms_key_id
}
