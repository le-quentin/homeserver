output "proxmox_networks" {
  description = "Proxmox network interfaces"
  value = {
    bridge_lan = {
      name    = proxmox_virtual_environment_network_linux_bridge.bridge_lan.name
      ip_cidr = proxmox_virtual_environment_network_linux_bridge.bridge_lan.address
      ip      = cidrhost(proxmox_virtual_environment_network_linux_bridge.bridge_lan.address, 0)
    }
    bridge_mgtlan = {
      name    = proxmox_virtual_environment_network_linux_bridge.bridge_mgtlan.name
      ip_cidr = proxmox_virtual_environment_network_linux_bridge.bridge_mgtlan.address
      ip      = cidrhost(proxmox_virtual_environment_network_linux_bridge.bridge_lan.address, 0)
    }
  }
}
