# Least privilege for the agent identity (principal derived from the deployed engine, nothing hardcoded).
locals {
  agent_principal = "principal://${google_vertex_ai_reasoning_engine.agent.spec[0].effective_identity}"
}

resource "google_project_iam_member" "agent" {
  for_each = toset([
    "roles/aiplatform.user",         # call Gemini on the regional endpoint and use the code sandbox
    "roles/browser",                 # start-up: resourcemanager.projects.get (project number -> ID)
    "roles/agentregistry.viewer",    # resolve registered endpoints through the Agent Gateway
    "roles/logging.logWriter",       # write the agent logs (token usage, duration)
    "roles/monitoring.metricWriter", # runtime metrics
    "roles/cloudtrace.agent",        # runtime traces
  ])

  project = var.project_id
  role    = each.value
  member  = local.agent_principal
}

# Read/write on the agent-workspace/ managed folder ONLY. Agent identities cannot hold the
# storage.legacyBucket* roles, so no bucket-level binding exists for them.
resource "google_storage_managed_folder_iam_member" "workspace" {
  bucket         = google_storage_bucket.data.name
  managed_folder = google_storage_managed_folder.workspace.name
  role           = "roles/storage.objectUser"
  member         = local.agent_principal
}

# Invoke the backend function (and nothing else)
resource "google_cloud_run_v2_service_iam_member" "agent_invokes_function" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.action.name
  role     = "roles/run.invoker"
  member   = local.agent_principal
}

# The Agent Gateway service agent resolves run.app through the private zone of samples/base (DNS peering of
# the egress connectivity template): roles/dns.peer is the role the VPC connectivity guide requires.
resource "google_project_iam_member" "agent_gateway_dns_peer" {
  project = var.project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${local.base.project_number}@gcp-sa-agentgateway.iam.gserviceaccount.com"
}
