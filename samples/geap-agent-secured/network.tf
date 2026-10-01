# Private Service Connect interface attachments on the dedicated /28 subnet of samples/base.
# The agent runtime and the gateway egress proxy reach the VPC through them (no public IP, no NAT).
resource "google_compute_network_attachment" "agent" {
  name                  = "na-${local.agent_name}"
  region                = var.region
  description           = "PSC interface of the agent runtime"
  connection_preference = "ACCEPT_AUTOMATIC" # only the Agent Platform tenant can reach this producer-side attachment
  subnetworks           = [local.base.subnet_psc_attach_id]
}

resource "google_compute_network_attachment" "gateway_egress" {
  name                  = "na-${local.agent_name}-egress"
  region                = var.region
  description           = "PSC interface of the egress agent gateway"
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [local.base.subnet_psc_attach_id]
}
