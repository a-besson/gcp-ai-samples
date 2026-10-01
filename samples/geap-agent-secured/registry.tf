# Agent Registry: every endpoint the agent may reach through the egress gateway is registered here,
# then granted roles/iap.egressor to the agent identity (policies.tf). Anything else is denied.
locals {
  # Exact hostnames only (no wildcards): standard and mTLS variants are listed separately.
  egress_endpoints = {
    aiplatform-regional      = "https://${var.region}-aiplatform.googleapis.com"
    aiplatform-regional-mtls = "https://${var.region}-aiplatform.mtls.googleapis.com"
    aiplatform               = "https://aiplatform.googleapis.com"
    aiplatform-mtls          = "https://aiplatform.mtls.googleapis.com"
    agentregistry            = "https://agentregistry.googleapis.com"
    logging                  = "https://logging.googleapis.com"
    logging-mtls             = "https://logging.mtls.googleapis.com"
    telemetry                = "https://telemetry.googleapis.com"
    telemetry-mtls           = "https://telemetry.mtls.googleapis.com"
    monitoring               = "https://monitoring.googleapis.com"
    monitoring-mtls          = "https://monitoring.mtls.googleapis.com"
    iamcredentials           = "https://iamcredentials.googleapis.com"
    iamcredentials-mtls      = "https://iamcredentials.mtls.googleapis.com"
    storage                  = "https://storage.googleapis.com"
    storage-mtls             = "https://storage.mtls.googleapis.com"
    backend-function         = google_cloudfunctions2_function.action.service_config[0].uri
  }
}

resource "google_agent_registry_service" "egress" {
  for_each = local.egress_endpoints

  location     = var.region
  service_id   = "${local.agent_name}-${each.key}"
  display_name = "${local.agent_name}-${each.key}"
  description  = "Egress endpoint allowed for ${local.agent_name}"

  interfaces {
    url              = each.value
    protocol_binding = "HTTP_JSON"
  }

  endpoint_spec {
    type = "NO_SPEC"
  }
}

# Registered services are ingested asynchronously into the registry catalogue
resource "time_sleep" "registry_ingestion" {
  depends_on      = [google_agent_registry_service.egress]
  create_duration = "60s"
}

data "google_agent_registry_endpoint" "egress" {
  for_each = local.egress_endpoints

  location   = var.region
  filter     = "displayName=\"${local.agent_name}-${each.key}\""
  depends_on = [time_sleep.registry_ingestion]
}
