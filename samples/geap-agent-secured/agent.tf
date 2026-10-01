# Agent Runtime engine: Agent Identity, CMEK, attached to the VPC, both gateways, sandboxed code.
resource "google_vertex_ai_reasoning_engine" "agent" {
  display_name = local.agent_name
  description  = "Secured ADK agent: scoped bucket access, backend function, sandboxed code execution"
  region       = var.region

  encryption_spec {
    kms_key_name = local.base.kms_key_id
  }

  spec {
    agent_framework = "google-adk"
    # Agent Identity is mandatory with agent_gateway_config; the service_account field must stay unset.
    identity_type = "AGENT_IDENTITY"

    source_code_spec {
      inline_source {
        source_archive = filebase64(var.agent_source_archive)
      }
      python_spec {
        version           = "3.13" # latest version supported by Agent Runtime
        entrypoint_module = "agent"
        entrypoint_object = "root_agent"
      }
    }

    deployment_spec {
      min_instances = var.min_instances
      max_instances = var.max_instances

      # Attach the agent to the Belgium VPC through Private Service Connect
      psc_interface_config {
        network_attachment = google_compute_network_attachment.agent.id
      }

      agent_gateway_config {
        client_to_agent_config {
          agent_gateway = google_network_services_agent_gateway.ingress.id
        }
        agent_to_anywhere_config {
          agent_gateway = google_network_services_agent_gateway.egress.id
        }
      }

      env {
        name  = "MODEL"
        value = var.model
      }
      env {
        name  = "MODEL_LOCATION"
        value = var.region
      }
      env {
        name  = "BUCKET"
        value = google_storage_bucket.data.name
      }
      env {
        name  = "FUNCTION_URL"
        value = google_cloudfunctions2_function.action.service_config[0].uri
      }
      # Agent Gateway egress needs the Agent Identity token to be usable for Google Cloud APIs
      # (value taken from the Agent Gateway runtime documentation).
      env {
        name  = "GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES"
        value = "false"
      }
    }
  }

  # The ingress Model Armor policy must be in place before the agent can receive traffic
  depends_on = [google_network_security_authz_policy.model_armor]
}
