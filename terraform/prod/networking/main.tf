module "networking" {
  source = "../../modules/networking"

  environment = "prod"
  pool        = "prod"

  networking_lan_name    = "vmbr1"
  networking_lan_cidr_ip = "10.42.1.1/24"

  apps_lan_name    = "vmbr10"
  apps_lan_cidr_ip = "10.42.10.1/24"
}

moved {
  from = module.networking.proxmox_virtual_environment_network_linux_bridge.bridge_lan
  to = module.networking.proxmox_virtual_environment_network_linux_bridge.networking_lan
}
