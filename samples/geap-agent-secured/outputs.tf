output "reasoning_engine_id" {
  description = "Full resource name of the deployed Agent Runtime engine."
  value       = google_vertex_ai_reasoning_engine.agent.name
}

output "agent_principal" {
  description = "IAM principal of the agent (Agent Identity)."
  value       = local.agent_principal
}

output "bucket_name" {
  description = "Data bucket; the agent only reaches the agent-workspace/ managed folder."
  value       = google_storage_bucket.data.name
}

output "function_url" {
  description = "Internal-only URL of the backend Cloud Run function."
  value       = google_cloudfunctions2_function.action.service_config[0].uri
}

output "gateway_ingress_id" {
  description = "ID of the CLIENT_TO_AGENT Agent Gateway (Model Armor)."
  value       = google_network_services_agent_gateway.ingress.id
}

output "gateway_egress_id" {
  description = "ID of the AGENT_TO_ANYWHERE Agent Gateway (default deny)."
  value       = google_network_services_agent_gateway.egress.id
}

output "egress_allowlist" {
  description = "Endpoints the agent identity is allowed to reach through the egress gateway."
  value       = local.egress_endpoints
}
