# Private zone resolving *.run.app to the PSC endpoint for Google APIs (network.tf), visible from the VPC only.
# Agent Gateways peer with it (dns_peering_config) to reach internal-only Cloud Run services.
resource "google_dns_managed_zone" "run_app" {
  name        = "priv-run-app"
  dns_name    = "run.app."
  description = "Cloud Run through the PSC endpoint for Google APIs"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = module.vpc.network_id
    }
  }
}

resource "google_dns_record_set" "run_app" {
  managed_zone = google_dns_managed_zone.run_app.name
  name         = "*.${google_dns_managed_zone.run_app.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc_google_apis.address]
}
