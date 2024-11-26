module "legacy" {
  source = "../../modules/legacy"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  zigbee_dongle_id = "1-2"
  vm_ids_offset    = 1000

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1001"
  bridge_lan_network_ip = "10.142.1.1"

  legacy_homeserver_vm = {
    address   = var.legacy_homeserver_address
    disk_size = 20
    dns       = "10.142.1.2"
    user = {
      ssh_key  = var.legacy_homeserver_ssh_key
      username = var.legacy_homeserver_username
    }
  }
}
