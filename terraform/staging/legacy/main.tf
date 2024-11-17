module "legacy" {
  source = "../../modules/legacy"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_ids_offset = 1000

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface   = "vmbr1001"
  bridge_lan_network_ip  = "10.142.1.100"
  legacy_vlan_network_ip = "10.142.200.1"

  legacy_homeserver_vm = {
    address = var.legacy_homeserver_address
    user = {
      ssh_key  = var.legacy_homeserver_ssh_key
      username = var.legacy_homeserver_username
    }
  }
}
