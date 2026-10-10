# Private Service Connect interface attachment on the dedicated /28 subnet of samples/base (a subnet can serve
# several network attachments: this one sits next to the attachment of geap-agent-secured). The egress gateway
# reaches the VPC through it. No public IP, no NAT. No Fabric module manages a standalone network attachment.
resource "google_compute_network_attachment" "gateway_egress" {
  name                  = "na-${local.agent_name}-egress"
  region                = var.region
  description           = "PSC interface of the egress agent gateway"
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [local.base.subnet_psc_attach_id]
}
