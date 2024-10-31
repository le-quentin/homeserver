variable "environment" {
  type = string
  description = "The current environment"
}

variable "pool" {
  type = string
  description = "The resources pool for this environment"
}

variable "node_name" {
  type = string
  description = "The name of the node (physical server) on which we'll deploy"
}

variable "bridge_lan_interface" {
  type = string
  description = "The name of the network interface for the global bridge LAN"
}

variable "bridge_lan_network_ip" {
  type = string
  description = "The ip address of the network for the the global bridge LAN"
}

resource "proxmox_virtual_environment_pool" pool {
  comment = "Staging environment pool"
  pool_id = var.pool
}

resource "proxmox_virtual_environment_network_linux_bridge" bridge_lan_interface {
  # depends_on = [
  #   proxmox_virtual_environment_network_linux_vlan.vlan99
  # ]

  node_name = var.node_name
  name = var.bridge_lan_interface 
  comment = "The global LAN for the ${var.environment} env"

  address = var.bridge_lan_network_ip

  vlan_aware = false

  ports = [
    # Network (or VLAN) interfaces to attach to the bridge, specified by their interface name
    # (e.g. "ens18.99" for VLAN 99 on interface ens18).
    # For VLAN interfaces with custom names, use the interface name without the VLAN tag, e.g. "vlan_lab"
  ]
}

resource "proxmox_virtual_environment_network_linux_vlan" "vlan_legacy" {
  node_name = var.node_name
  comment = "The LAN for legacy (=all dockers on hone host) homeserver"
  # name      = "vlan_legacy"

  ## or alternatively, use custom name:
  name      = "vlan_legacy"
  interface = var.bridge_lan_interface
  vlan      = 1001
}
