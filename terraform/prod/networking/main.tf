module "networking" {
  source = "../../modules/networking"

  environment = "prod"
  pool        = "prod"

  networking_lan_name    = "vmbr1"
  networking_lan_cidr_ip = "10.42.1.1/24"

  k3s_lan_name    = "vmbr10"
  k3s_lan_cidr_ip = "10.42.10.1/24"
}
