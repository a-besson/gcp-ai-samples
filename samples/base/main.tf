# Shared foundations for all GEAP samples: provider config, API activation, naming.
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    # Waits for new service agents to be visible to IAM
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    # Only for google_project_service_identity (service agents)
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Required by the billing budget API (quota is charged to the project)
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

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  prefix = "gcp-samples"

  # `project` label is prefixed with gcp-samples_ (underscores only, no slashes)
  labels = {
    project    = "gcp-samples_base"
    env        = var.env
    managed-by = "terraform"
  }

  # APIs needed by base and by the samples that consume it
  apis = [
    "agentidentity.googleapis.com", # Agent Identity
    "agentregistry.googleapis.com",
    "aiplatform.googleapis.com",
    "apphub.googleapis.com",      # App Hub
    "apptopology.googleapis.com", # App Topology
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudapiregistry.googleapis.com", # Cloud API Registry
    "cloudasset.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com", # Dataform
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "modelarmor.googleapis.com",
    "monitoring.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
    "notebooks.googleapis.com",     # Notebooks
    "observability.googleapis.com", # Observability
    "run.googleapis.com",
    "saasservicemgmt.googleapis.com", # App Lifecycle Manager
    "securitycenter.googleapis.com",  # Security Command Center
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "telemetry.googleapis.com",
    "texttospeech.googleapis.com", # Cloud Text-to-Speech
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
