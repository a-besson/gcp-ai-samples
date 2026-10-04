# Agent Policy: IAM egress allowlist enforced by IAP on the egress gateway (always on) + semantic
# governance (optional, Preview).

# IAM agent policy: the agent identity may only reach the registered endpoints.
# registry_resource is the endpoint created with the service (.../endpoints/<id>): reading it from the
# resource keeps new grants "known after apply", unlike a registry lookup by display name at plan time.
resource "google_iap_agent_registry_endpoint_iam_member" "egress" {
  for_each = local.egress_endpoints

  project     = var.project_id
  location    = var.region
  endpoint_id = reverse(split("/", google_agent_registry_service.egress[each.key].registry_resource))[0]
  role        = "roles/iap.egressor"
  member      = local.agent_principal
}

# The grants above are only evaluated once IAP is the egress gateway's authorizer: without this
# REQUEST_AUTHZ policy the gateway applies its built-in default_denied rule to every request.
# V1 = IAM Allow policy (the roles/iap.egressor bindings); V2 (Unified Access Policy) would ignore them.
resource "google_network_services_authz_extension" "iap_egress" {
  name     = "agw-iap-egress"
  location = var.region

  service = "iap.googleapis.com"
  timeout = "1s"
  # Fail closed: if IAP cannot decide, the egress request is denied
  fail_open = false

  metadata = {
    iapPolicyVersion = "V1"
  }
}

resource "google_network_security_authz_policy" "iap_egress" {
  name           = "agw-iap-egress"
  location       = var.region
  policy_profile = "REQUEST_AUTHZ"
  action         = "CUSTOM"

  target {
    resources = [google_network_services_agent_gateway.egress.id]
  }

  custom_provider {
    authz_extension {
      resources = [google_network_services_authz_extension.iap_egress.id]
    }
  }
}

# Egress decisions (iap.resources.egressViaIAP) are Data Access audit logs, off by default: enable them
# so that a denied destination (labels."iap.googleapis.com/audited_resource_name" = unregisteredResource
# or a missing grant) can be diagnosed from Cloud Logging.
resource "google_project_iam_audit_config" "iap" {
  project = var.project_id
  service = "iap.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
}

# --- Semantic governance (flag enable_semantic_governance) ---------------------------------------
# The deployed agent is ingested into Agent Registry, which gives the policy its agent ID.
# NOTE: this provisions the policy engine and the agent-scope policy. Wiring the engine to the
# egress gateway (authz extension + authz policy on the model-inference paths) is documented in the
# README because it needs the engine DNS hostname, which the provider does not expose.
resource "google_vertex_ai_semantic_governance_policy_engine" "this" {
  count = var.enable_semantic_governance ? 1 : 0

  region = var.region
}

resource "time_sleep" "agent_ingestion" {
  count = var.enable_semantic_governance ? 1 : 0

  depends_on      = [google_vertex_ai_reasoning_engine.agent]
  create_duration = "120s"
}

data "google_agent_registry_agent" "this" {
  count = var.enable_semantic_governance ? 1 : 0

  location   = var.region
  filter     = "displayName=\"${local.agent_name}\""
  depends_on = [time_sleep.agent_ingestion]
}

resource "google_vertex_ai_semantic_governance_policy" "agent_scope" {
  count = var.enable_semantic_governance ? 1 : 0

  region                        = var.region
  semantic_governance_policy_id = "sgp-${local.agent_name}"
  display_name                  = "${local.agent_name} scope"
  agent                         = data.google_agent_registry_agent.this[0].id
  natural_language_constraint   = var.semantic_policy

  depends_on = [google_vertex_ai_semantic_governance_policy_engine.this]
}
