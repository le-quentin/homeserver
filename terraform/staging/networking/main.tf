module "networking" {
  source = "../../modules/networking"

  environment = "staging"
  pool        = "staging"

  bridge_lan_name       = "vmbr1001"
  bridge_lan_cidr_ip    = "10.142.1.100/16"
  bridge_mgtlan_name    = "vmbr1100"
  bridge_mgtlan_cidr_ip = "10.143.1.100/16"
}
