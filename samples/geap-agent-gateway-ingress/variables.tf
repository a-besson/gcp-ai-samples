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
  description = "Region of every resource (agent engine, gateway, Model Armor templates). Locked to Belgium for data sovereignty."
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
  description = "Claude model served by Vertex AI in model_location (partner model, enabled in Model Garden), or a Gemini model as a temporary fallback while Claude has no quota. Check it with `task check-model` before changing it."
  default     = "claude-haiku-5-5"

  validation {
    condition     = can(regex("^(claude-[a-z0-9-]+(@[0-9]{8})?|gemini-[a-z0-9.-]+)$", var.model))
    error_message = "model must be a Claude model ID on Vertex AI (e.g. claude-haiku-5-5), or a Gemini fallback (e.g. gemini-3.8-flash)."
  }
}

variable "model_location" {
  type        = string
  description = "EU location whose Vertex AI endpoint serves the model: the eu multi-region (default) or an EU member-state region. Inference stays in the EU; the resources stay in var.region."
  default     = "eu"

  # EU member-state regions and the "eu" multi-region only: europe-west2 (UK), europe-west6 (Switzerland) and
  # "global" (no data residency) are excluded.
  validation {
    condition = contains([
      "eu", "europe-central2", "europe-north1", "europe-north2", "europe-southwest1", "europe-west1", "europe-west3",
      "europe-west4", "europe-west8", "europe-west9", "europe-west10", "europe-west12",
    ], var.model_location)
    error_message = "model_location must be the eu multi-region or an EU region (e.g. eu): data sovereignty requirement."
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
