# Private Service Connect interface attachment on the dedicated /28 subnet of samples/base.
# The egress gateway reaches the VPC through it, and so does the agent (the API does not allow a
# direct PSC interface on an engine that uses an Agent Gateway). No public IP, no NAT.
resource "google_compute_network_attachment" "gateway_egress" {
  name                  = "na-${local.agent_name}-egress"
  region                = var.region
  description           = "PSC interface of the egress agent gateway"
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [local.base.subnet_psc_attach_id]
}
