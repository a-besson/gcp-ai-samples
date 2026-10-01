# Offline assertions on the base invariants. `apply` runs against mocked providers:
# no credentials, no cloud call.
mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "time" {}

# Project billing link not readable by default (as with an unknown account)
override_data {
  target = data.google_project.this
  values = {
    number          = "123456789012"
    billing_account = ""
  }
}

variables {
  project_id      = "my-gcp-project-id"
  billing_account = "ABCDEF-123456-ABCDEF"
}

run "sovereignty_and_security_invariants" {
  command = apply

  assert {
    condition     = module.kms.keyring != null
    error_message = "The KMS key ring must be created."
  }

  assert {
    condition     = google_artifact_registry_repository.docker.location == "europe-west1"
    error_message = "Artifact Registry must be in europe-west1."
  }

  assert {
    condition     = google_artifact_registry_repository.docker.kms_key_name != null
    error_message = "Artifact Registry must use the shared CMEK key."
  }

  assert {
    condition     = google_logging_project_bucket_config.regional.location == "europe-west1"
    error_message = "The log bucket must be regional (europe-west1)."
  }

  assert {
    condition     = google_billing_budget.this[0].display_name == "budget-gcp-samples"
    error_message = "Budget must be created when billing_account is set."
  }
}

run "labels_use_project_prefix" {
  command = apply

  assert {
    condition     = local.labels["project"] == "gcp-samples_base" && local.labels["managed-by"] == "terraform"
    error_message = "default labels must carry project=gcp-samples_base and managed-by=terraform."
  }
}

run "budget_disabled_without_billing_account" {
  command = apply

  variables {
    billing_account = null
  }

  assert {
    condition     = length(google_billing_budget.this) == 0
    error_message = "No budget without billing_account."
  }
}

run "rejects_non_belgium_region" {
  command = plan

  variables {
    region = "europe-west4"
  }

  expect_failures = [var.region]
}

run "rejects_excessive_budget" {
  command = plan

  variables {
    budget_amount = 5000
  }

  expect_failures = [var.budget_amount]
}

run "budget_disabled_with_empty_billing_account" {
  command = apply

  variables {
    billing_account = ""
  }

  assert {
    condition     = length(google_billing_budget.this) == 0
    error_message = "An empty billing_account must disable the budget instead of failing."
  }
}

run "rejects_malformed_billing_account" {
  command = plan

  variables {
    billing_account = "my-gcp-project-id"
  }

  expect_failures = [var.billing_account]
}

run "budget_uses_the_billing_account_linked_to_the_project" {
  command = apply

  variables {
    billing_account = null
  }

  override_data {
    target = data.google_project.this
    values = {
      number          = "123456789012"
      billing_account = "ABCDEF-123456-ABCDEF"
    }
  }

  assert {
    condition     = length(google_billing_budget.this) == 1 && google_billing_budget.this[0].billing_account == "ABCDEF-123456-ABCDEF"
    error_message = "The budget must fall back to the billing account linked to the project."
  }
}

run "cmek_is_granted_to_the_service_agents" {
  command = apply

  variables {
    extra_cmek_service_agents = ["service-123456789012@gcp-sa-aiplatform-re.iam.gserviceaccount.com"]
  }

  assert {
    condition     = toset(keys(google_kms_crypto_key_iam_member.cmek_users)) == toset(["storage", "artifact_registry", "aiplatform", "extra_0"])
    error_message = "The key must be granted to storage, Artifact Registry, Agent Platform and the extra agents."
  }

  assert {
    condition     = alltrue([for m in google_kms_crypto_key_iam_member.cmek_users : m.role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"])
    error_message = "Service agents must only get encrypter/decrypter on the key."
  }
}

run "rejects_non_service_account_emails" {
  command = plan

  variables {
    extra_cmek_service_agents = ["someone@example.com"]
  }

  expect_failures = [var.extra_cmek_service_agents]
}
