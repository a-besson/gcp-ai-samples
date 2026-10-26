output "reasoning_engine_id" {
  description = "Full resource name of the deployed Agent Runtime engine."
  value       = module.agent.id
}

output "agent_principal" {
  description = "IAM principal of the agent (Agent Identity)."
  value       = local.agent_principal
}

output "gateway_ingress_id" {
  description = "ID of the CLIENT_TO_AGENT Agent Gateway (Model Armor)."
  value       = module.gateway_ingress.id
}

output "request_template_id" {
  description = "Model Armor template screening the client prompts."
  value       = google_model_armor_template.this["request"].id
}

output "response_template_id" {
  description = "Model Armor template screening the agent answers."
  value       = google_model_armor_template.this["response"].id
}

output "log_view" {
  description = "Log view of the regional bucket of samples/base, holding the Model Armor sanitization logs (read by `task e2e`)."
  value       = "${local.base.log_bucket_id}/views/_AllLogs"
}
