module "k3s_node" {
  source = "../../modules/k3s_node"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_ids_offset  = 2000
  vm_name        = "k3s-server"
  vm_description = "The k3s server node, running both the control plane and a kubelet for pods hosting"

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1010"
  bridge_lan_network_ip = "10.142.10.1"

  # usb_mappings = [
  #   { device_id = "toto" }
  # ]

  vm_params = {
    address   = var.vm_address
    disk_size = 30
    dns       = "10.142.1.2"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }
}
