# Ingress Agent Gateway (clients -> agent) from the Fabric geap-agent-gateway module, in the region of the agent.
# Model Armor screens every streamQuery prompt and answer with the templates of model_armor.tf. The module
# configures its own provider (networkservices v1alpha1 endpoint): the provider default_labels do not reach its
# resources, so labels are passed explicitly, and the module cannot be used with depends_on, count or for_each.
locals {
  model_armor_config = {
    request_template_id  = google_model_armor_template.this["request"].id
    response_template_id = google_model_armor_template.this["response"].id
    # Fail closed (also the module default, set explicitly): if Model Armor is unreachable or refuses the
    # callout, the request is denied rather than let through unscreened
    fail_open = false
  }
}

module "gateway_ingress" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-gateway?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id     = var.project_id
  project_number = local.base.project_number
  region         = var.region
  name           = "agw-${local.agent_name}"
  description    = "Governs client-to-agent traffic: Model Armor screens prompts and answers"
  access_path    = "CLIENT_TO_AGENT"
  labels         = local.labels
  registries     = [local.registry]

  # Content screening only, as in geap-agent-secured: IAM allow policies do not apply to ingress traffic
  iap_config         = null
  model_armor_config = local.model_armor_config
}
