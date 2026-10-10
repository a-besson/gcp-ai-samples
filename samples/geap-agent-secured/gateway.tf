# Two Agent Gateways, one per governed access path (same project and region as the agent), from the Fabric
# geap-agent-gateway module. The module configures its own provider (networkservices v1alpha1 endpoint): the
# provider default_labels do not reach its resources, so labels are passed explicitly, and the module cannot be
# used with depends_on, count or for_each.

# Ingress: clients -> agent. Model Armor screens prompts and answers (templates in model_armor.tf).
module "gateway_ingress" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id     = var.project_id
  project_number = local.base.project_number
  region         = var.region
  name           = "agw-${local.agent_name}-ingress"
  description    = "Governs client-to-agent traffic"
  access_path    = "CLIENT_TO_AGENT"
  labels         = local.labels
  registries     = [local.registry]

  # Content screening only, as in geap-agent-secured: no IAP request authorization on the way in
  iap_config = null
  # Fail closed (module default): if Model Armor is unreachable the request is denied rather than let through
  model_armor_config = {
    request_template_id  = google_model_armor_template.this["request"].id
    response_template_id = google_model_armor_template.this["response"].id
  }
}

# Egress: agent -> anywhere. Default deny: the module attaches IAP as the gateway authorizer (REQUEST_AUTHZ,
# IAM allow policies V1, fail closed); only endpoints registered in Agent Registry (registry.tf) and granted
# roles/iap.egressor to the agent identity are reachable.
module "gateway_egress" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id     = var.project_id
  project_number = local.base.project_number
  region         = var.region
  name           = "agw-${local.agent_name}-egress"
  description    = "Governs agent-to-anywhere traffic (default deny)"
  access_path    = "AGENT_TO_ANYWHERE"
  labels         = local.labels
  registries     = [local.registry]

  # The module manages the connectivity template. The internal-only function is reached through the VPC: run.app
  # resolves to the PSC endpoint for Google APIs (private zone of samples/base), so the call enters Cloud Run from
  # the VPC instead of the internet.
  # NOTE: the API refuses to update a template referenced by a gateway, and the module does not replace it before
  # destroying the old one: changing these settings needs the gateway detached first (see README).
  # The attachment is passed through the module context: the module counts its template on the literal key, which
  # is known at plan time, while the attachment id is only known after apply.
  networking_config = {
    psc_i_network_attachment_id = "$psc_network_attachments:egress"
    labels                      = local.labels
    dns_peering_config = {
      domains        = [local.base.run_app_private_dns_name]
      target_network = local.base.network_id
    }
  }
  context = {
    psc_network_attachments = {
      egress = google_compute_network_attachment.gateway_egress.id
    }
  }

  # The roles/iap.egressor grants are in registry.tf: see the note there.
}
