module "networking" {
  source = "../../modules/firewall"

  environment = "prod"
  pool        = "prod"
}
