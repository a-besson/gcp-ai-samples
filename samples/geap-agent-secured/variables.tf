variable "project_id" {
  type        = string
  description = "GCP project ID hosting the samples (from GCP_PROJECT_ID in .env)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "region" {
  type        = string
  description = "Region of every resource (agent engine, gateways, bucket, function). Locked to Belgium for data sovereignty."
  default     = "europe-west1"

  validation {
    condition     = var.region == "europe-west1"
    error_message = "region must be europe-west1 (Belgium): data sovereignty requirement."
  }
}

variable "env" {
  type        = string
  description = "Environment label applied to every resource."
  default     = "sandbox"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,30}$", var.env))
    error_message = "env must be a valid GCP label value."
  }
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding the Terraform state of samples/base (TF_STATE_BUCKET in .env)."

  validation {
    condition     = length(var.state_bucket) > 0
    error_message = "state_bucket must not be empty."
  }
}

variable "model" {
  type        = string
  description = "Gemini model name, served by the regional endpoint of model_location. Check availability before changing it (europe-west1 serves gemini-2.5-* only)."
  default     = "gemini-3.5-flash"

  validation {
    condition     = can(regex("^gemini-[a-z0-9.-]+$", var.model))
    error_message = "model must be a Gemini model name (e.g. gemini-3.5-flash)."
  }
}

variable "model_location" {
  type        = string
  description = "EU region whose regional endpoint serves the model. Inference stays in the EU; the resources stay in var.region."
  default     = "europe-west3"

  # EU member-state regions only: europe-west2 (UK) and europe-west6 (Switzerland) are excluded, and so is
  # the "eu" multi-region, whose mTLS host (used under Agent Identity) does not exist.
  validation {
    condition = contains([
      "europe-central2", "europe-north1", "europe-north2", "europe-southwest1", "europe-west1", "europe-west3",
      "europe-west4", "europe-west8", "europe-west9", "europe-west10", "europe-west12",
    ], var.model_location)
    error_message = "model_location must be an EU region (e.g. europe-west3): data sovereignty requirement."
  }
}

variable "min_instances" {
  type        = number
  description = "Minimum warm instances (0 = scale to zero, cheapest)."
  default     = 0

  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 1
    error_message = "min_instances must be 0 or 1 to bound the cost."
  }
}

variable "max_instances" {
  type        = number
  description = "Maximum instances, bounded to protect the budget."
  default     = 2

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 3
    error_message = "max_instances must be between 1 and 3."
  }
}

variable "agent_source_archive" {
  type        = string
  description = "Path to the agent source tar.gz built by `task package` (main file at the archive root)."
  default     = "build/agent_src.tar.gz"
}

variable "function_source_dir" {
  type        = string
  description = "Directory holding the Cloud Run function source (main.py, requirements.txt)."
  default     = "function_src"
}

variable "enable_semantic_governance" {
  type        = bool
  description = "Provision the semantic governance policy engine and an agent-scope policy (Preview, billed per LLM evaluation)."
  default     = false
}

variable "semantic_policy" {
  type        = string
  description = "Natural-language constraint enforced by the semantic governance policy (only used when enable_semantic_governance is true)."
  default     = "The agent only writes plain-text reports under agent-workspace/ and only calls the backend function with a small JSON payload."
}
