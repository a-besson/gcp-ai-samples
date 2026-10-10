# Agent Runtime engine from the Fabric geap-agent-runtime module: Agent Identity, CMEK, both gateways (VPC access
# through the egress gateway), least-privilege project roles for the agent identity, sandboxed code.
module "agent" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/geap-agent-runtime?ref=25d8d9a0ca869fd15083a16183f61de1408524e3"

  project_id  = var.project_id
  region      = var.region
  name        = local.agent_name
  description = "Secured ADK agent: scoped bucket access, backend function, sandboxed code execution"

  encryption_key = local.base.kms_key_id

  # deletion_policy = FORCE: the engine owns child resources Terraform does not manage (sessions, the sandbox of
  # `task sandbox`), and the API refuses to delete it otherwise (FAILED_PRECONDITION "contains child resources")
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
      # Region of the engine itself (sessions, sandbox), distinct from the model location
      ENGINE_LOCATION = var.region
      BUCKET          = module.bucket.name
      FUNCTION_URL    = module.function.function.service_config[0].uri
      # Agent Gateway egress needs the Agent Identity token to be usable for Google Cloud APIs
      # (value taken from the Agent Gateway runtime documentation).
      GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES = "false"
    }
  }

  deployment_config = {
    source_files_config = {
      source_path = var.agent_source_archive
      python_spec = {
        entrypoint_module = "agent"
        entrypoint_object = "adk_app" # AdkApp wrapper exposing the query methods
      }
    }
  }

  # The API forbids a direct PSC interface together with gateways: the VPC is reached through the egress gateway
  networking_config = {
    agent_gateways = {
      # Built from the gateway name, known at plan: on an in-place update of the engine, the google-beta provider
      # drops a client_to_agent_config whose gateway id is only known after apply (observed 2026-10-10: the
      # binding was missing from the plan). The reference still creates the gateway first.
      ingress = "projects/${var.project_id}/locations/${var.region}/agentGateways/${module.gateway_ingress.agent_gateway.name}"
      egress  = module.gateway_egress.id
    }
  }

  # Project roles granted to the agent identity (the module default would add storage.objectViewer on every bucket)
  service_account_config = {
    roles = [
      "roles/aiplatform.user",         # call Gemini on the regional endpoint and use the code sandbox
      "roles/browser",                 # start-up: resourcemanager.projects.get (project number -> ID)
      "roles/agentregistry.viewer",    # resolve registered endpoints through the Agent Gateway
      "roles/logging.logWriter",       # write the agent logs (token usage, duration)
      "roles/monitoring.metricWriter", # runtime metrics
      "roles/cloudtrace.agent",        # runtime traces
    ]
  }

  # The ingress Model Armor policy must be in place before the agent can receive traffic
  depends_on = [module.gateway_ingress]
}

locals {
  # IAM principal of the agent (Agent Identity), derived from the deployed engine: nothing hardcoded
  agent_principal = module.agent.identity
}
