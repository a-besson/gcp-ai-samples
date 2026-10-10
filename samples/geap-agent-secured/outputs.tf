output "reasoning_engine_id" {
  description = "Full resource name of the deployed Agent Runtime engine."
  value       = module.agent.id
}

output "agent_principal" {
  description = "IAM principal of the agent (Agent Identity)."
  value       = local.agent_principal
}

output "bucket_name" {
  description = "Data bucket; the agent only reaches the agent-workspace/ managed folder."
  value       = module.bucket.name
}

output "function_url" {
  description = "Internal-only URL of the backend Cloud Run function."
  value       = module.function.function.service_config[0].uri
}

output "gateway_ingress_id" {
  description = "ID of the CLIENT_TO_AGENT Agent Gateway (Model Armor)."
  value       = module.gateway_ingress.id
}

output "gateway_egress_id" {
  description = "ID of the AGENT_TO_ANYWHERE Agent Gateway (default deny)."
  value       = module.gateway_egress.id
}

output "connectivity_template_id" {
  description = "Agent connectivity template of the egress gateway (project-number form)."
  value       = module.gateway_egress.connectivity_template_id
}

output "egress_allowlist" {
  description = "Endpoints the agent identity is allowed to reach through the egress gateway."
  value       = local.egress_endpoints
}
