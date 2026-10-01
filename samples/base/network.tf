# Belgium VPC: no public IP, no NAT, Private Google Access. Human access goes through IAP tunnels.
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.3"

  project_id   = var.project_id
  network_name = "vpc-${local.prefix}"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name               = "snet-workloads-ew1"
      subnet_ip                 = "10.10.0.0/24"
      subnet_region             = var.region
      subnet_private_access     = "true" # reach Google APIs without public IP
      subnet_flow_logs          = "true"
      subnet_flow_logs_sampling = "0.5"
      subnet_flow_logs_interval = "INTERVAL_10_MIN"
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
      description               = "Workloads and function connectivity"
    },
    {
      # Reserved for Private Service Connect interface network attachments (agents, gateway egress)
      subnet_name               = "snet-psc-attach-ew1"
      subnet_ip                 = "10.10.1.0/28"
      subnet_region             = var.region
      subnet_private_access     = "true"
      subnet_flow_logs          = "true"
      subnet_flow_logs_sampling = "0.5"
      subnet_flow_logs_interval = "INTERVAL_10_MIN"
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
      description               = "PSC interface network attachments"
    },
  ]

  # Explicit, logged deny-all ingress: nothing is reachable from outside the VPC by default.
  # Egress: there is no NAT and no external IP, so there is no path to the internet by design;
  # Google APIs are reached through Private Google Access.
  ingress_rules = [
    {
      name          = "deny-all-ingress"
      description   = "Default deny, logged. Add narrow allow rules per sample (ports commented)."
      priority      = 65000
      source_ranges = ["0.0.0.0/0"]
      deny          = [{ protocol = "all" }]
      log_config    = { metadata = "INCLUDE_ALL_METADATA" }
    },
  ]

  depends_on = [google_project_service.apis]
}
