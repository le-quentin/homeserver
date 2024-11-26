module "legacy" {
  source = "../../modules/legacy"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_ids_offset = 1000

  vm_cpu_cores        = 4
  vm_dedicated_memory = 6144
  vm_floating_memory  = 6144

  zigbee_dongle_id = "1-4"

  environment = "prod"
  pool        = "prod"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1"
  bridge_lan_network_ip = "10.42.1.1"

  legacy_homeserver_vm = {
    address   = var.legacy_homeserver_address
    disk_size = 100
    dns       = "10.42.1.2"
    user = {
      ssh_key  = var.legacy_homeserver_ssh_key
      username = var.legacy_homeserver_username
    }
  }
}
