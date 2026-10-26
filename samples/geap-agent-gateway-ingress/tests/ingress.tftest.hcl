# Offline assertions on the security invariants (mocked providers and remote state, no credentials).
mock_provider "google" {}
mock_provider "google-beta" {}

# The Fabric geap-agent-gateway module configures its own providers, which mock_provider does not reach: without
# this override `terraform test` would call the real API with the local credentials. Its behaviour is covered by
# the Fabric test suite; the assertions below check the wiring of this configuration.
override_module {
  target = module.gateway_ingress
  outputs = {
    id                       = "projects/my-gcp-project-id/locations/europe-west1/agentGateways/agw-geap-agent-gateway-ingress"
    agent_gateway            = { name = "agw-geap-agent-gateway-ingress" }
    connectivity_template_id = null
    authz_policy_ids         = { model_armor = "projects/my-gcp-project-id/locations/europe-west1/authzPolicies/agw-geap-agent-gateway-ingress-ma" }
  }
}

override_data {
  target = data.terraform_remote_state.base
  values = {
    outputs = {
      kms_key_id     = "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
      project_number = "123456789012"
      log_bucket_id  = "projects/my-gcp-project-id/locations/europe-west1/buckets/logs-gcp-samples-ew1"
    }
  }
}

variables {
  project_id           = "my-gcp-project-id"
  state_bucket         = "my-gcp-project-id-tfstate"
  agent_source_archive = "tests/fixtures/agent_src.tar.gz"
}

run "agent_uses_agent_identity_cmek_and_the_ingress_gateway_only" {
  command = apply

  assert {
    condition     = module.agent.agent.spec[0].identity_type == "AGENT_IDENTITY"
    error_message = "The agent must use Agent Identity."
  }

  assert {
    condition     = module.agent.agent.spec[0].service_account == null || module.agent.agent.spec[0].service_account == ""
    error_message = "No service account must be set with Agent Identity."
  }

  assert {
    condition     = module.agent.agent.encryption_spec[0].kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The engine must be encrypted with the shared CMEK key."
  }

  assert {
    condition     = module.agent.agent.spec[0].deployment_spec[0].agent_gateway_config[0].client_to_agent_config[0].agent_gateway == module.gateway_ingress.id
    error_message = "The engine must be bound to the ingress gateway of this sample."
  }

  assert {
    condition     = length(module.agent.agent.spec[0].deployment_spec[0].agent_gateway_config[0].agent_to_anywhere_config) == 0
    error_message = "No egress gateway: the agent reaches Vertex AI directly."
  }

  assert {
    condition     = length(module.agent.agent.spec[0].deployment_spec[0].psc_interface_config) == 0
    error_message = "psc_interface_config and agent_gateway_config cannot be set together: no direct PSC interface."
  }

  assert {
    condition     = module.agent.agent.region == "europe-west1"
    error_message = "The agent must be deployed in europe-west1."
  }

  assert {
    condition     = module.agent.agent.spec[0].deployment_spec[0].max_instances <= 3
    error_message = "max_instances must stay bounded."
  }
}

run "destroy_removes_the_engine_sessions" {
  command = apply

  assert {
    condition     = module.agent.agent.deletion_policy == "FORCE"
    error_message = "The engine must be deleted with its sessions (deletion_policy FORCE), or task destroy fails."
  }
}

run "templates_block_prompt_injection_and_log_verdicts" {
  command = apply

  assert {
    condition     = alltrue([for t in google_model_armor_template.this : t.location == "europe-west1"])
    error_message = "Model Armor templates must be in the gateway region (cross-region calls are not supported)."
  }

  assert {
    condition     = alltrue([for t in google_model_armor_template.this : t.filter_config[0].pi_and_jailbreak_filter_settings[0].filter_enforcement == "ENABLED" && t.filter_config[0].pi_and_jailbreak_filter_settings[0].confidence_level == "MEDIUM_AND_ABOVE"])
    error_message = "Prompt injection and jailbreak detection must be enabled at MEDIUM_AND_ABOVE."
  }

  assert {
    condition     = alltrue([for t in google_model_armor_template.this : t.template_metadata[0].enforcement_type == "INSPECT_AND_BLOCK"])
    error_message = "Templates must block on a match, not only inspect."
  }

  assert {
    condition     = alltrue([for t in google_model_armor_template.this : t.template_metadata[0].log_sanitize_operations])
    error_message = "Sanitization verdicts must be logged (evidence of each block)."
  }
}

run "gateway_screens_with_model_armor_and_fails_closed" {
  command = apply

  assert {
    condition     = local.model_armor_config.request_template_id == google_model_armor_template.this["request"].id && local.model_armor_config.response_template_id == google_model_armor_template.this["response"].id
    error_message = "The gateway must screen prompts and answers with the templates of this sample."
  }

  assert {
    condition     = local.model_armor_config.fail_open == false
    error_message = "The Model Armor policy must fail closed."
  }
}

run "agent_runtime_service_agent_can_call_model_armor" {
  command = apply

  assert {
    condition     = toset(keys(google_project_iam_member.model_armor_callout)) == toset(["roles/modelarmor.calloutUser", "roles/modelarmor.user"])
    error_message = "The Agent Runtime service agent needs the Model Armor callout and user roles."
  }

  assert {
    condition     = alltrue([for m in google_project_iam_member.model_armor_callout : m.member == "serviceAccount:service-123456789012@gcp-sa-aiplatform-re.iam.gserviceaccount.com"])
    error_message = "Model Armor roles must go to the Agent Runtime service agent only."
  }
}

run "claude_runs_in_the_eu_with_unbound_tokens" {
  command = plan

  assert {
    condition     = contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL=claude-haiku-5-5") && contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL_LOCATION=eu")
    error_message = "The agent must call claude-haiku-5-5 on the eu multi-region by default."
  }

  assert {
    condition     = contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES=false")
    error_message = "The Anthropic client (no mTLS) needs unbound Agent Identity tokens."
  }
}

run "accepts_an_eu_member_state_region" {
  command = plan

  variables {
    model_location = "europe-west1"
  }
}

run "rejects_non_eu_model_location" {
  command = plan

  variables {
    model_location = "global"
  }

  expect_failures = [var.model_location]
}

run "accepts_the_gemini_fallback" {
  command = plan

  variables {
    model = "gemini-3.8-flash"
  }

  assert {
    condition     = contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL=gemini-3.8-flash")
    error_message = "The Gemini fallback must reach the agent environment."
  }
}

run "rejects_other_model_families" {
  command = plan

  variables {
    model = "gpt-4o"
  }

  expect_failures = [var.model]
}

run "labels_use_project_prefix" {
  command = plan

  assert {
    condition     = local.labels["project"] == "gcp-samples_geap-agent-gateway-ingress"
    error_message = "The project label must be prefixed with gcp-samples_."
  }
}

run "rejects_non_belgium_region" {
  command = plan

  variables {
    region = "europe-west3"
  }

  expect_failures = [var.region]
}
