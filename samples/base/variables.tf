variable "project_id" {
  type        = string
  description = "GCP project ID hosting all samples (from GCP_PROJECT_ID in .env)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits, hyphens)."
  }
}

variable "region" {
  type        = string
  description = "Region of every regional resource. Locked to Belgium for data sovereignty."
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
    error_message = "env must be a valid GCP label value (lowercase letters, digits, hyphens, underscores)."
  }
}

variable "billing_account" {
  type        = string
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX) for the budget alerts. Null or empty: use the billing account linked to the project when readable, otherwise no budget."
  default     = null

  validation {
    condition     = var.billing_account == null ? true : (var.billing_account == "" || can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account)))
    error_message = "billing_account must look like XXXXXX-XXXXXX-XXXXXX (uppercase hexadecimal)."
  }
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget amount (in budget_currency) triggering the 50/90/100 % alerts. Bounded to protect the bill."
  default     = 50

  validation {
    condition     = var.budget_amount > 0 && var.budget_amount <= 500
    error_message = "budget_amount must be between 1 and 500."
  }
}

variable "budget_currency" {
  type        = string
  description = "ISO 4217 currency of the budget; must match the billing account currency."
  default     = "EUR"
}

variable "log_retention_days" {
  type        = number
  description = "Retention of the regional (europe-west1) log bucket, in days."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 365
    error_message = "log_retention_days must be between 1 and 365."
  }
}
