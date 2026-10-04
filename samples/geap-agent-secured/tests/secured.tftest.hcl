# Offline assertions on the security invariants (mocked providers and remote state, no credentials).
mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "archive" {}
mock_provider "time" {}

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
    condition     = google_storage_bucket.data.public_access_prevention == "enforced" && google_storage_bucket.data.uniform_bucket_level_access
    error_message = "The data bucket must enforce public access prevention and uniform access."
  }

  assert {
    condition     = google_storage_bucket.data.location == "europe-west1"
    error_message = "The data bucket must be in europe-west1."
  }

  assert {
    condition     = google_storage_bucket.data.encryption[0].default_kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The data bucket must use the shared CMEK key."
  }

  assert {
    condition     = google_storage_managed_folder.workspace.name == "agent-workspace/"
    error_message = "The workspace must be a managed folder named agent-workspace/."
  }

  assert {
    condition     = google_storage_managed_folder_iam_member.workspace.role == "roles/storage.objectUser"
    error_message = "The agent gets objectUser on the managed folder only."
  }
}

run "agent_identity_has_least_privilege" {
  command = apply

  assert {
    condition     = toset(keys(google_project_iam_member.agent)) == toset(["roles/aiplatform.user", "roles/browser", "roles/agentregistry.viewer", "roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/cloudtrace.agent"])
    error_message = "Project-level roles of the agent must be exactly the documented runtime roles (no editor/owner)."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.agent_invokes_function.role == "roles/run.invoker"
    error_message = "The agent may only invoke the backend function."
  }
}

run "function_is_internal_only_with_dedicated_accounts" {
  command = apply

  assert {
    condition     = google_cloudfunctions2_function.action.service_config[0].ingress_settings == "ALLOW_INTERNAL_ONLY"
    error_message = "The function must not accept internet traffic."
  }

  assert {
    condition     = google_cloudfunctions2_function.action.service_config[0].service_account_email == google_service_account.function_runtime.email
    error_message = "The function must run as its dedicated service account."
  }

  assert {
    condition     = google_cloudfunctions2_function.action.kms_key_name == "projects/my-gcp-project-id/locations/europe-west1/keyRings/kr-gcp-samples/cryptoKeys/key-gcp-samples"
    error_message = "The function must use the shared CMEK key."
  }
}

run "function_service_agents_can_use_the_key" {
  command = apply

  assert {
    condition     = toset(keys(google_kms_crypto_key_iam_member.function_agents)) == toset(["cloudfunctions.googleapis.com", "run.googleapis.com"])
    error_message = "The Cloud Functions and Cloud Run service agents must be granted on the shared key."
  }
}

run "function_builds_into_the_full_repository_path" {
  command = apply

  assert {
    condition     = google_cloudfunctions2_function.action.build_config[0].docker_repository == "projects/my-gcp-project-id/locations/europe-west1/repositories/ar-gcp-samples"
    error_message = "The function docker_repository must be the full repository path."
  }
}

run "two_gateways_with_model_armor_on_ingress" {
  command = apply

  assert {
    condition     = google_network_services_agent_gateway.ingress.google_managed[0].governed_access_path == "CLIENT_TO_AGENT"
    error_message = "The ingress gateway must be CLIENT_TO_AGENT."
  }

  assert {
    condition     = google_network_services_agent_gateway.egress.google_managed[0].governed_access_path == "AGENT_TO_ANYWHERE"
    error_message = "The egress gateway must be AGENT_TO_ANYWHERE."
  }

  assert {
    condition     = google_network_services_agent_gateway.ingress.location == "europe-west1" && google_network_services_agent_gateway.egress.location == "europe-west1"
    error_message = "Gateways must be in europe-west1."
  }

  assert {
    condition     = strcontains(google_network_services_agent_gateway.egress.agent_connectivity_template, "projects/123456789012/")
    error_message = "The connectivity template must be referenced by project number."
  }

  assert {
    condition     = google_network_security_authz_policy.model_armor.policy_profile == "CONTENT_AUTHZ" && google_network_security_authz_policy.model_armor.action == "CUSTOM"
    error_message = "Model Armor must be enforced with a CONTENT_AUTHZ / CUSTOM authz policy."
  }

  assert {
    condition     = google_network_services_authz_extension.model_armor.service == "modelarmor.europe-west1.rep.googleapis.com" && !google_network_services_authz_extension.model_armor.fail_open
    error_message = "Model Armor must use the regional endpoint and fail closed."
  }
}

run "agent_reaches_the_vpc_through_the_egress_gateway" {
  command = apply

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.spec[0].identity_type == "AGENT_IDENTITY"
    error_message = "The agent must use Agent Identity."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.spec[0].service_account == null || google_vertex_ai_reasoning_engine.agent.spec[0].service_account == ""
    error_message = "No service account must be set with Agent Identity."
  }

  assert {
    condition     = length(google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].psc_interface_config) == 0
    error_message = "psc_interface_config and agent_gateway_config cannot be set together: no direct PSC interface."
  }

  assert {
    condition     = google_network_services_agent_connectivity_template.egress.egress_network_config[0].network_attachment != null
    error_message = "The egress gateway must reach the VPC through a network attachment."
  }

  assert {
    condition     = length(google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].agent_gateway_config[0].client_to_agent_config) == 1 && length(google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].agent_gateway_config[0].agent_to_anywhere_config) == 1
    error_message = "Both client_to_agent and agent_to_anywhere gateways must be configured."
  }

  assert {
    condition     = google_vertex_ai_reasoning_engine.agent.region == "europe-west1"
    error_message = "The agent must be deployed in europe-west1."
  }
}

run "every_egress_endpoint_is_registered_and_granted" {
  command = apply

  assert {
    condition     = length(google_agent_registry_service.egress) == length(local.egress_endpoints) && length(google_iap_agent_registry_endpoint_iam_member.egress) == length(local.egress_endpoints)
    error_message = "Each egress endpoint must be registered and granted roles/iap.egressor."
  }

  assert {
    condition     = alltrue([for key in ["cloudresourcemanager", "cloudresourcemanager-mtls", "aiplatform-regional-mtls", "aiplatform-rep", "cloudtrace", "secretmanager"] : contains(keys(local.egress_endpoints), key)])
    error_message = "The start-up and session endpoints required by Agent Runtime must be on the allowlist."
  }

  assert {
    condition     = alltrue([for s in google_agent_registry_service.egress : s.interfaces[0].protocol_binding == "JSONRPC"])
    error_message = "Egress endpoints must be registered with the JSONRPC binding used by the gateway documentation."
  }

  assert {
    condition     = alltrue([for m in google_iap_agent_registry_endpoint_iam_member.egress : m.role == "roles/iap.egressor"])
    error_message = "Egress grants must use roles/iap.egressor only."
  }
}

run "internal_function_is_reached_through_the_vpc" {
  command = apply

  assert {
    condition     = google_network_services_agent_connectivity_template.egress.egress_network_config[0].dns_peering_config[0].domains == tolist(["run.app."]) && google_network_services_agent_connectivity_template.egress.egress_network_config[0].dns_peering_config[0].target_network == "projects/my-gcp-project-id/global/networks/vpc-gcp-samples"
    error_message = "run.app must be resolved through the VPC private zone (PSC endpoint for Google APIs)."
  }

  assert {
    condition     = google_project_iam_member.agent_gateway_dns_peer.role == "roles/dns.peer" && google_project_iam_member.agent_gateway_dns_peer.member == "serviceAccount:service-123456789012@gcp-sa-agentgateway.iam.gserviceaccount.com"
    error_message = "The Agent Gateway service agent needs roles/dns.peer for the DNS peering."
  }

  assert {
    condition     = google_cloudfunctions2_function.action.service_config[0].ingress_settings == "ALLOW_INTERNAL_ONLY"
    error_message = "The backend function must stay internal-only."
  }
}

run "model_runs_in_an_eu_region_on_the_allowlist" {
  command = plan

  assert {
    condition     = contains([for e in google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "MODEL_LOCATION=europe-west3") && contains([for e in google_vertex_ai_reasoning_engine.agent.spec[0].deployment_spec[0].env : "${e.name}=${e.value}"], "ENGINE_LOCATION=europe-west1")
    error_message = "The model must run in europe-west3 by default while the engine stays in europe-west1."
  }

  assert {
    condition     = local.egress_endpoints["model-mtls"] == "https://europe-west3-aiplatform.mtls.googleapis.com" && local.egress_endpoints["model"] == "https://europe-west3-aiplatform.googleapis.com"
    error_message = "The model endpoint (standard and mTLS) must be on the egress allowlist."
  }
}

run "no_extra_model_endpoint_when_the_model_runs_in_the_engine_region" {
  command = plan

  variables {
    model_location = "europe-west1"
  }

  assert {
    condition     = !contains(keys(local.egress_endpoints), "model")
    error_message = "The regional aiplatform hosts already cover a model in the engine region."
  }
}

run "rejects_non_eu_model_location" {
  command = plan

  variables {
    model_location = "europe-west2"
  }

  expect_failures = [var.model_location]
}

run "egress_gateway_delegates_authorization_to_iap" {
  command = apply

  assert {
    condition     = google_network_security_authz_policy.iap_egress.policy_profile == "REQUEST_AUTHZ" && google_network_security_authz_policy.iap_egress.action == "CUSTOM" && google_network_security_authz_policy.iap_egress.target[0].resources == tolist([google_network_services_agent_gateway.egress.id])
    error_message = "The egress gateway must delegate request authorization to IAP (REQUEST_AUTHZ / CUSTOM)."
  }

  assert {
    condition     = google_network_services_authz_extension.iap_egress.service == "iap.googleapis.com" && !google_network_services_authz_extension.iap_egress.fail_open && google_network_services_authz_extension.iap_egress.metadata["iapPolicyVersion"] == "V1"
    error_message = "The IAP extension must fail closed and evaluate the IAM Allow policy (V1) holding the iap.egressor grants."
  }
}

run "egress_decisions_are_audited" {
  command = apply

  assert {
    condition     = google_project_iam_audit_config.iap.service == "iap.googleapis.com"
    error_message = "IAP Data Access audit logs must be enabled to diagnose egress denials."
  }
}

run "semantic_governance_is_off_by_default" {
  command = plan

  assert {
    condition     = length(google_vertex_ai_semantic_governance_policy_engine.this) == 0
    error_message = "Semantic governance must be disabled by default (Preview, billed)."
  }
}

run "semantic_governance_can_be_enabled" {
  command = apply

  variables {
    enable_semantic_governance = true
  }

  assert {
    condition     = length(google_vertex_ai_semantic_governance_policy.agent_scope) == 1
    error_message = "Enabling the flag must create the agent-scope policy."
  }
}

run "labels_use_project_prefix" {
  command = plan

  assert {
    condition     = local.labels["project"] == "gcp-samples_geap-agent-secured"
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
