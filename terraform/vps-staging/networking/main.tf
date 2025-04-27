# Done here for now because networking is probably the very first thing to setup, so this will be run first
resource "proxmox_virtual_environment_pool" "pool" {
  comment = "vps-staging environment pool"
  pool_id = "vps-staging"
}

resource "proxmox_virtual_environment_network_linux_bridge" "networking_lan" {
  node_name = "beelink"
  name      = "vmbr5001"
  address   = "10.150.1.1/24"
  comment   = "vps-staging network"
}

