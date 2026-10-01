# Two Agent Gateways, one per governed access path (same project and region as the agent).

# Ingress: clients -> agent. Model Armor screens prompts and answers (see model_armor.tf).
resource "google_network_services_agent_gateway" "ingress" {
  name        = "agw-${local.agent_name}-ingress"
  location    = var.region
  description = "Governs client-to-agent traffic"

  google_managed {
    governed_access_path = "CLIENT_TO_AGENT"
  }

  registries = [local.registry]
}

# Egress: agent -> anywhere. Default deny: only endpoints registered in Agent Registry and granted
# roles/iap.egressor to the agent identity are reachable (see registry.tf).
resource "google_network_services_agent_connectivity_template" "egress" {
  agent_connectivity_template_id = "act-${local.agent_name}-egress"
  location                       = var.region
  description                    = "Egress path of the agent gateway through the VPC"
  access_path                    = "AGENT_TO_ANYWHERE"

  egress_network_config {
    network_attachment = google_compute_network_attachment.gateway_egress.id
  }
}

resource "google_network_services_agent_gateway" "egress" {
  name        = "agw-${local.agent_name}-egress"
  location    = var.region
  description = "Governs agent-to-anywhere traffic (default deny)"

  google_managed {
    governed_access_path = "AGENT_TO_ANYWHERE"
  }

  # The template is referenced by project NUMBER (not ID): a project ID is silently rejected
  agent_connectivity_template = "projects/${local.base.project_number}/locations/${var.region}/agentConnectivityTemplates/${google_network_services_agent_connectivity_template.egress.agent_connectivity_template_id}"

  registries = [local.registry]
}
