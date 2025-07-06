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
resource "proxmox_virtual_environment_time" "node_time" {
  node_name = var.node_name
  time_zone = "CET"
}

resource "proxmox_virtual_environment_network_linux_bridge" "networking_lan" {
  node_name = var.node_name
  name      = var.networking_lan_name
  address   = var.networking_lan_cidr_ip
  comment   = "${var.environment} network apps (DNS, router, DHCP...)  LAN"
}

resource "proxmox_virtual_environment_network_linux_bridge" "apps_lan" {
  node_name = var.node_name
  name      = var.apps_lan_name
  address   = var.apps_lan_cidr_ip
  comment   = "${var.environment} apps cluster LAN"
}

