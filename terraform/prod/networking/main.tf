module "networking" {
  source = "../../modules/networking"

  environment = "prod"
  pool        = "prod"

  bridge_lan_name    = "vmbr1"
  bridge_lan_cidr_ip = "10.42.1.1/24"
}
