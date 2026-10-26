# Model Armor templates screened by the ingress gateway: the client prompt on the way in (request), the agent
# answer on the way out (response). Fabric has no module for them: the geap-agent-gateway module takes their ids
# and creates the authz extension and the CONTENT_AUTHZ policy. Templates must be in the gateway region.
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
    # Prompt injection and jailbreak detection: the threat this sample is about
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
    # Block (not only inspect) on a match, explicitly rather than through the API default
    enforcement_type = "INSPECT_AND_BLOCK"
    # Sanitization verdicts in Cloud Logging (regional bucket of samples/base): evidence of each block
    log_sanitize_operations = true
    log_template_operations = true

    multi_language_detection {
      enable_multi_language_detection = true
    }
  }
}
