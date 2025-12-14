module "dns" {
  source = "../../modules/dns"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_ids_offset = 1000

  vm_cpu_cores        = 2
  vm_dedicated_memory = 1024
  vm_floating_memory  = 1024

  environment = "prod"
  pool        = "prod"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1"
  bridge_lan_network_ip = "10.42.1.1"

  main_dns = true

  firewall_enabled = false

  dns_vm = {
    address      = var.dns_vm_address
    cidr_address = "${var.dns_vm_address}/${var.dns_vm_cidr_suffix}"
    disk_size    = 30
    user = {
      ssh_key  = var.dns_vm_ssh_key
      username = var.dns_vm_username
    }
  }
}
