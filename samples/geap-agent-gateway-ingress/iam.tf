# Ingress screening: the Agent Runtime service agent calls Model Armor for the gateway (Model Armor / Agent Gateway
# integration documentation: Model Armor Callout User in the agent project, Model Armor User in the template
# project, the same project here). The service agent is created with the first engine of the project, hence
# the dependency. It is shared by every engine of the project: no other sample binds these roles to it.
resource "google_project_iam_member" "model_armor_callout" {
  for_each = toset([
    "roles/modelarmor.calloutUser",
    "roles/modelarmor.user",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:service-${local.base.project_number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"

  depends_on = [module.agent]
}
