module "networking" {
  source = "../../modules/networking"

  environment = "staging"
  pool        = "staging"

  networking_lan_name    = "vmbr1001"
  networking_lan_cidr_ip = "10.142.1.1/24"

  apps_lan_name    = "vmbr1010"
  apps_lan_cidr_ip = "10.142.10.1/24"
}
