# Offline assertions on the security invariants (mocked providers and remote state, no credentials).
mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "archive" {}
mock_provider "time" {}

# The Fabric geap-agent-gateway module configures its own providers, which mock_provider does not reach: without
# these overrides `terraform test` would call the real API with the local credentials. Their behaviour is covered
# by the Fabric test suite; the assertions below check the wiring of this configuration.
override_module {
  target = module.gateway_ingress
  outputs = {
    id                       = "projects/my-gcp-project-id/locations/europe-west1/agentGateways/agw-geap-agent-secured-ingress"
    agent_gateway            = { name = "agw-geap-agent-secured-ingress" }
    connectivity_template_id = null
    authz_policy_ids         = { model_armor = "projects/my-gcp-project-id/locations/europe-west1/authzPolicies/agw-geap-agent-secured-ingress-ma" }
  }
}

override_module {
  target = module.gateway_egress
  outputs = {
    id                       = "projects/my-gcp-project-id/locations/europe-west1/agentGateways/agw-geap-agent-secured-egress"
    connectivity_template_id = "projects/123456789012/locations/europe-west1/agentConnectivityTemplates/agw-geap-agent-secured-egress"
    authz_policy_ids         = { iap = "projects/my-gcp-project-id/locations/europe-west1/authzPolicies/agw-geap-agent-secured-egress-iap" }
  }
}

override_data {
  target = data.terraform_remote_state.base
  values = {
    outputs = {
      kms_key_id                      = "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
      project_number                  = "123456789012"
      subnet_psc_attach_id            = "projects/my-gcp-project-id/regions/europe-west1/subnetworks/snet-psc-attach-ew1"
      artifact_registry_repository_id = "ar-gcp-samples"
      network_id                      = "projects/my-gcp-project-id/global/networks/vpc-gcp-samples"
      run_app_private_dns_name        = "run.app."
    }
  }
}

variables {
  project_id           = "my-gcp-project-id"
  state_bucket         = "my-gcp-project-id-tfstate"
  agent_source_archive = "tests/fixtures/agent_src.tar.gz"
}

run "data_bucket_is_private_encrypted_and_scoped" {
  command = apply

  assert {
    condition     = module.bucket.bucket.public_access_prevention == "enforced" && module.bucket.bucket.uniform_bucket_level_access
    error_message = "The data bucket must enforce public access prevention and uniform access."
  }

  assert {
    condition     = module.bucket.bucket.location == "EUROPE-WEST1" || module.bucket.bucket.location == "europe-west1"
    error_message = "The data bucket must be in europe-west1."
  }

  assert {
    condition     = module.bucket.bucket.encryption[0].default_kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The data bucket must be encrypted with the shared CMEK key."
  }
}

run "agent_uses_agent_identity_cmek_and_both_gateways" {
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
    condition     = length(module.agent.agent.spec[0].deployment_spec[0].psc_interface_config) == 0
    error_message = "psc_interface_config and agent_gateway_config cannot be set together: no direct PSC interface."
  }

  assert {
    condition     = module.agent.agent.spec[0].deployment_spec[0].agent_gateway_config[0].client_to_agent_config[0].agent_gateway == module.gateway_ingress.id && module.agent.agent.spec[0].deployment_spec[0].agent_gateway_config[0].agent_to_anywhere_config[0].agent_gateway == module.gateway_egress.id
    error_message = "The engine must be bound to the ingress and egress gateways of this sample."
  }

  assert {
    condition     = module.agent.agent.region == "europe-west1"
    error_message = "The agent must be deployed in europe-west1."
  }
}

run "destroy_removes_the_engine_children" {
  command = apply

  assert {
    condition     = module.agent.agent.deletion_policy == "FORCE"
    error_message = "The engine must be deleted with its sessions and sandbox (deletion_policy FORCE), or task destroy fails."
  }
}

run "function_is_internal_only_with_dedicated_accounts" {
  command = apply

  assert {
    condition     = module.function.function.service_config[0].ingress_settings == "ALLOW_INTERNAL_ONLY"
    error_message = "The function must only accept internal traffic."
  }

  assert {
    condition     = module.function.function.kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The function must be encrypted with the shared CMEK key."
  }

  assert {
    condition     = module.function.function.service_config[0].service_account_email == module.function.service_account_email && module.function.service_account_email != null
    error_message = "The function must run as its dedicated service account."
  }

  assert {
    condition     = module.function.function.build_config[0].service_account == module.function_build_sa.id
    error_message = "The function must build with its dedicated build service account."
  }

  assert {
    condition     = module.function.function.build_config[0].docker_repository == "projects/my-gcp-project-id/locations/europe-west1/repositories/ar-gcp-samples"
    error_message = "The function must build into the full CMEK repository path."
  }
}

run "egress_reaches_the_vpc_through_an_attachment_on_the_base_subnet" {
  command = apply

  assert {
    condition     = contains(google_compute_network_attachment.gateway_egress.subnetworks, "projects/my-gcp-project-id/regions/europe-west1/subnetworks/snet-psc-attach-ew1")
    error_message = "The egress gateway attachment must use the PSC subnet of samples/base."
  }

  assert {
    condition     = google_compute_network_attachment.gateway_egress.connection_preference == "ACCEPT_AUTOMATIC"
    error_message = "Agent Gateway requires an ACCEPT_AUTOMATIC network attachment."
  }
}

run "every_egress_endpoint_is_registered_and_granted" {
  command = apply

  assert {
    condition     = toset(keys(google_agent_registry_service.egress)) == toset(keys(local.egress_endpoints))
    error_message = "Every egress endpoint must be registered in Agent Registry."
  }

  assert {
    condition     = toset(keys(google_iap_agent_registry_endpoint_iam_member.egress)) == toset(keys(local.egress_endpoints))
    error_message = "Every registered endpoint must be granted to the agent identity."
  }

  assert {
    condition     = alltrue([for m in google_iap_agent_registry_endpoint_iam_member.egress : m.role == "roles/iap.egressor" && m.member == local.agent_principal])
    error_message = "Egress grants must be roles/iap.egressor for the agent identity only."
  }

  assert {
    condition     = local.egress_endpoints["backend-function"] == module.function.function.service_config[0].uri
    error_message = "The backend function must be on the egress allowlist."
  }
}

run "model_runs_in_an_eu_region_on_the_allowlist" {
  command = apply

  assert {
    condition     = contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL_LOCATION=europe-west3") && contains([for e in module.agent.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "ENGINE_LOCATION=europe-west1")
    error_message = "The model must run in europe-west3 while the engine stays in europe-west1."
  }

  assert {
    condition     = contains(keys(local.egress_endpoints), "model") && contains(keys(local.egress_endpoints), "model-mtls")
    error_message = "The regional model endpoint (standard and mTLS) must be on the egress allowlist."
  }
}

run "rejects_non_eu_model_location" {
  command = plan

  variables {
    model_location = "us-central1"
  }

  expect_failures = [var.model_location]
}

run "semantic_governance_is_off_by_default" {
  command = apply

  assert {
    condition     = length(google_vertex_ai_semantic_governance_policy_engine.this) == 0
    error_message = "Semantic governance must be opt-in."
  }
}

run "labels_use_project_prefix" {
  command = plan

  assert {
    condition     = local.labels["project"] == "gcp-samples_geap-agent-secured"
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
