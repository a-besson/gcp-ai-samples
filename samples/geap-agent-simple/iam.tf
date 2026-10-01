# Least privilege for the agent identity (principal derived from the deployed engine, nothing hardcoded).
locals {
  agent_principal = "principal://${google_vertex_ai_reasoning_engine.agent.spec[0].effective_identity}"
}

resource "google_project_iam_member" "agent" {
  for_each = toset([
    "roles/aiplatform.user",   # call Gemini on the regional endpoint
    "roles/logging.logWriter", # write the agent logs (token usage, duration)
  ])

  project = var.project_id
  role    = each.value
  member  = local.agent_principal
}
