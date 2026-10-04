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
locals {
  egress_network = {
    network_attachment = google_compute_network_attachment.gateway_egress.id
    # The backend function is internal-only: run.app resolves to the PSC endpoint for Google APIs of the
    # VPC (private zone in samples/base), so the call enters Cloud Run from the VPC instead of the internet.
    dns_domains = [local.base.run_app_private_dns_name]
    dns_network = local.base.network_id
  }
}

# The API refuses to update a template referenced by a gateway: any change creates a new template (ID suffixed
# by a hash of its network settings), switches the gateway to it, then deletes the previous one.
resource "google_network_services_agent_connectivity_template" "egress" {
  agent_connectivity_template_id = "act-${local.agent_name}-egress-${substr(sha256(jsonencode(local.egress_network)), 0, 8)}"
  location                       = var.region
  description                    = "Egress path of the agent gateway through the VPC"
  access_path                    = "AGENT_TO_ANYWHERE"

  egress_network_config {
    network_attachment = local.egress_network.network_attachment

    dns_peering_config {
      domains        = local.egress_network.dns_domains
      target_network = local.egress_network.dns_network
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_iam_member.agent_gateway_dns_peer]
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
