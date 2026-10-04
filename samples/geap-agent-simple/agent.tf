# Agent Runtime deployment from source (no container to build), protected by the shared CMEK key.
resource "google_vertex_ai_reasoning_engine" "agent" {
  display_name = local.agent_name
  description  = "Simple ADK agent answering a question through an LLM"
  region       = var.region

  encryption_spec {
    kms_key_name = local.kms_key_id
  }

  spec {
    agent_framework = "google-adk"
    # Agent Identity: no service account, no key. The service_account field must stay unset.
    identity_type = "AGENT_IDENTITY"

    source_code_spec {
      inline_source {
        source_archive = filebase64(var.agent_source_archive)
      }
      python_spec {
        version           = "3.13" # latest version supported by Agent Runtime
        entrypoint_module = "agent"
        entrypoint_object = "adk_app" # AdkApp wrapper exposing the query methods
      }
    }

    deployment_spec {
      min_instances = var.min_instances
      max_instances = var.max_instances

      env {
        name  = "MODEL"
        value = var.model
      }
      env {
        name  = "MODEL_LOCATION"
        value = var.model_location
      }
    }
  }
}
