module "networking" {
  source = "../../modules/firewall"

  environment = "staging"
  pool        = "staging"

  icmp_enabled = true
}
