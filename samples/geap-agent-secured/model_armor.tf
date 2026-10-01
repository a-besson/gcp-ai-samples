# Model Armor templates enforced by the ingress gateway (user prompt in, agent answer out).
locals {
  model_armor_templates = {
    request  = "ma-${local.agent_name}-request"
    response = "ma-${local.agent_name}-response"
  }
}

resource "google_model_armor_template" "this" {
  for_each = local.model_armor_templates

  location    = var.region
  template_id = each.value

  filter_config {
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    rai_settings {
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    multi_language_detection {
      enable_multi_language_detection = true
    }
  }
}

# Authz extension calling the regional Model Armor endpoint (data stays in europe-west1)
resource "google_network_services_authz_extension" "model_armor" {
  name     = "agw-model-armor"
  location = var.region

  service = "modelarmor.${var.region}.rep.googleapis.com"
  timeout = "1s"
  # Fail closed: if Model Armor is unreachable the request is denied rather than let through unscreened
  fail_open = false

  metadata = {
    model_armor_settings = jsonencode([{
      request_template_id  = google_model_armor_template.this["request"].id
      response_template_id = google_model_armor_template.this["response"].id
    }])
  }
}

resource "google_network_security_authz_policy" "model_armor" {
  name           = "agw-model-armor"
  location       = var.region
  policy_profile = "CONTENT_AUTHZ"
  action         = "CUSTOM"

  target {
    resources = [google_network_services_agent_gateway.ingress.id]
  }

  custom_provider {
    authz_extension {
      resources = [google_network_services_authz_extension.model_armor.id]
    }
  }
}
