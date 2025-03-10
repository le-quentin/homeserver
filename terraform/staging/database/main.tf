module "database" {
  source = "../../modules/vm"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    # debian = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_id       = 2021
  name        = "database"
  description = "Database server, running PostgreSQL for various services"

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1010"
  bridge_lan_network_ip = "10.142.10.1"

  vm_cpu_cores        = 2
  vm_dedicated_memory = 2048
  vm_floating_memory  = 2048 # Disable ballooning because k3s doesn't like swapping
  vm_params = {
    address   = var.vm_address
    disk_size = 20
    dns       = "10.142.1.2"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }
}
# TODO add firewall for security
