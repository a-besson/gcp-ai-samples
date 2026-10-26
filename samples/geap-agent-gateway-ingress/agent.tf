# Agent Runtime engine from the Fabric geap-agent-runtime module: Agent Identity, CMEK, bound to the ingress
# gateway only (no egress gateway: the agent reaches Vertex AI directly, as geap-agent-simple does).
module "agent" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-runtime?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id  = var.project_id
  region      = var.region
  name        = local.agent_name
  description = "ADK agent answering with Claude, behind an ingress Agent Gateway with Model Armor"

  encryption_key = local.base.kms_key_id

  # deletion_policy = FORCE: the engine owns sessions Terraform does not manage, and the API refuses to delete
  # it otherwise (FAILED_PRECONDITION "contains child resources")
  enable_deletion_protection = false

  agent_runtime_config = {
    agent_framework = "google-adk"
    # Agent Identity is mandatory with an Agent Gateway; the module then leaves the service account unset
    identity_type  = "AGENT_IDENTITY"
    python_version = "3.13" # latest version supported by Agent Runtime
    min_instances  = var.min_instances
    max_instances  = var.max_instances
    environment_variables = {
      MODEL          = var.model
      MODEL_LOCATION = var.model_location
      # The Anthropic SDK calls Vertex AI without mTLS: an Agent Identity token bound to the agent certificate
      # would be refused, so the agent gets unbound tokens (Agent Gateway documentation, ADR 006)
      GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES = "false"
    }
  }

  deployment_config = {
    source_files_config = {
      source_path = var.agent_source_archive
      python_spec = {
        entrypoint_module = "agent"
        entrypoint_object = "adk_app" # AdkApp wrapper exposing only the screened query method
      }
    }
  }

  networking_config = {
    agent_gateways = {
      # Built from the gateway name, known at plan: on an in-place update of the engine, the google-beta provider
      # drops a client_to_agent_config whose gateway id is only known after apply (see geap-agent-secured)
      ingress = "projects/${var.project_id}/locations/${var.region}/agentGateways/${module.gateway_ingress.agent_gateway.name}"
    }
  }

  # Project roles granted to the agent identity (the module default would add storage.objectViewer on every bucket)
  service_account_config = {
    roles = [
      "roles/aiplatform.user",   # call the model on Vertex AI (Claude rawPredict, Gemini generateContent), use the managed sessions
      "roles/logging.logWriter", # write the agent logs (token usage, duration)
    ]
  }

  # The ingress Model Armor policy must be in place before the agent can receive traffic
  depends_on = [module.gateway_ingress]
}

locals {
  # IAM principal of the agent (Agent Identity), derived from the deployed engine: nothing hardcoded
  agent_principal = module.agent.identity
}
