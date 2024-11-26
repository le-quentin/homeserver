terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

# Done here for now because networking is probably the very first thing to setup, so this will be run first
resource "proxmox_virtual_environment_pool" "pool" {
  comment = "${var.environment} environment pool"
  pool_id = var.pool
}

resource "proxmox_virtual_environment_network_linux_bridge" "bridge_lan" {
  node_name = var.node_name
  name      = var.bridge_lan_name
  address   = var.bridge_lan_cidr_ip
  comment   = "${var.environment} global LAN"
}

