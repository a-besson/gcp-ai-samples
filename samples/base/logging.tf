# Keep application logs in Belgium: a regional bucket receives everything, and the global
# _Default sink is told to exclude it. _Required (audit logs) stays global — it cannot be moved.
resource "google_logging_project_bucket_config" "regional" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "logs-${local.prefix}-ew1"
  retention_days = var.log_retention_days

  depends_on = [google_project_service.apis]
}

resource "google_logging_project_sink" "regional" {
  project     = var.project_id
  name        = "sink-${local.prefix}-ew1"
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.regional.id}"
  filter      = "severity >= DEFAULT"
}

resource "google_logging_project_exclusion" "default_sink" {
  project     = var.project_id
  name        = "exclude-from-global-default"
  description = "Logs are stored in the europe-west1 bucket instead of the global _Default bucket."
  filter      = "severity >= DEFAULT"
}
