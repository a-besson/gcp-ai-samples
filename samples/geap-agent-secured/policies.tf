# Agent Policy: IAM egress allowlist (always on) + semantic governance (optional, Preview).

# IAM agent policy: the agent identity may only reach the registered endpoints
resource "google_iap_agent_registry_endpoint_iam_member" "egress" {
  for_each = local.egress_endpoints

  project     = var.project_id
  location    = var.region
  endpoint_id = data.google_agent_registry_endpoint.egress[each.key].endpoint_id
  role        = "roles/iap.egressor"
  member      = local.agent_principal
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
