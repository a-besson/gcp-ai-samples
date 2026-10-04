# Offline assertions (mocked providers, mocked base remote state, committed archive fixture).
mock_provider "google" {}

override_data {
  target = data.terraform_remote_state.base
  values = {
    outputs = {
      kms_key_id = "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    }
  }
}

variables {
  project_id           = "my-gcp-project-id"
  state_bucket         = "my-gcp-project-id-tfstate"
  agent_source_archive = "tests/fixtures/agent_src.tar.gz"
}

run "agent_is_sovereign_secured_and_identity_based" {
  command = apply

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.region == "europe-west1"
    error_message = "The agent must be deployed in europe-west1."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.spec[0].identity_type == "AGENT_IDENTITY"
    error_message = "The agent must use Agent Identity."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.spec[0].service_account == null || google_vertex_ai_reasoning_engine.agent.spec[0].service_account == ""
    error_message = "No service account must be set with Agent Identity."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.encryption_spec[0].kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The agent must be encrypted with the shared CMEK key."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].max_instances <= 3
    error_message = "max_instances must stay bounded."
  }
}

run "labels_use_project_prefix" {
  command = plan

  assert {
    condition     = local.labels["project"] == "gcp-samples_geap-agent-simple"
    error_message = "The project label must be prefixed with gcp-samples_ (no slash)."
  }
}

run "rejects_non_belgium_region" {
  command = plan

  variables {
    region = "us-central1"
  }

  expect_failures = [var.region]
}

run "rejects_unbounded_instances" {
  command = plan

  variables {
    max_instances = 50
  }

  expect_failures = [var.max_instances]
}

run "model_runs_in_an_eu_region" {
  command = plan

  assert {
    condition     = contains([for e in google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL_LOCATION=europe-west3")
    error_message = "The model must run in europe-west3 by default while the agent stays in europe-west1."
  }
}

run "rejects_non_eu_model_location" {
  command = plan

  variables {
    model_location = "europe-west2"
  }

  expect_failures = [var.model_location]
}
