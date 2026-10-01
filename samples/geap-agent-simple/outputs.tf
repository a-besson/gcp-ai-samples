output "reasoning_engine_id" {
  description = "Full resource name of the deployed Agent Runtime engine."
  value       = google_vertex_ai_reasoning_engine.agent.name
}

output "agent_principal" {
  description = "IAM principal of the agent (Agent Identity)."
  value       = local.agent_principal
}
