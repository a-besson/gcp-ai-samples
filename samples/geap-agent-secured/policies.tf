# Agent Policy. The IAM egress allowlist (IAP authz extension, REQUEST_AUTHZ policy, roles/iap.egressor grants)
# is created by the egress gateway module (gateway.tf); this file holds the optional semantic governance (Preview).
#
# Not repeated here (project-wide, owned by geap-agent-secured): the Data Access audit logs of iap.googleapis.com.
# The IAP decision of each egress request is in the gateway log anyway (jsonPayload.authzPolicyInfo.result).

# --- Semantic governance (flag enable_semantic_governance) ---------------------------------------
# The deployed agent is ingested into Agent Registry, which gives the policy its agent ID.
# NOTE: this provisions the policy engine and the agent-scope policy. Wiring the engine to the
# egress gateway (authz extension + authz policy on the model-inference paths) is documented in the
# README because it needs the engine DNS hostname, which the provider does not expose.
# The policy engine is regional: enable the flag in one sample of the project only.
resource "google_vertex_ai_semantic_governance_policy_engine" "this" {
  count = var.enable_semantic_governance ? 1 : 0

  region = var.region
}

resource "time_sleep" "agent_ingestion" {
  count = var.enable_semantic_governance ? 1 : 0

  depends_on      = [module.agent]
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
