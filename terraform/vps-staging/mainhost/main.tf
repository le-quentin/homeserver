module "vps_mainhost_staging" {
  source = "../../modules/vm"

  vm_id       = 5001
  name        = "vps-mainhost-staging"
  description = "Test vps deployments locally"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  environment = "vps-staging"
  pool        = "vps-staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr5001"
  bridge_lan_network_ip = "10.150.1.1"

  vm_cpu_cores        = 1
  vm_dedicated_memory = 2048
  # vm_floating_memory  = 2048

  vm_params = {
    address   = var.vm_address
    disk_size = 20
    dns       = "1.1.1.1"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }
}
