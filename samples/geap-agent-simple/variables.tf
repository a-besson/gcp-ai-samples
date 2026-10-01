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
  description = "Region of the agent and of the model endpoint. Locked to Belgium for data sovereignty."
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
  description = "Gemini model name served by the regional europe-west1 endpoint. Check availability before changing it."
  default     = "gemini-3.5-flash"

  validation {
    condition     = can(regex("^gemini-[a-z0-9.-]+$", var.model))
    error_message = "model must be a Gemini model name (e.g. gemini-3.5-flash)."
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
