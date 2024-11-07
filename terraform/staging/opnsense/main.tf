module "opnsense" {
  source = "../../modules/opnsense"

  environment = "staging"
  pool        = "staging"

  vm_ids_offset = 1000

  opnsense_vm_template_id = 1998

  bridge_lan_interface             = "vmbr1001"
  bridge_lan_network_ip            = "10.142.1.100"
  bridge_management_lan_interface  = "vmbr1100"
  bridge_management_lan_network_ip = "10.143.1.100"
  legacy_vlan_network_ip           = "10.142.200.1"
  sshmgt_vlan_network_ip           = "10.142.254.1"

}
