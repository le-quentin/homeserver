module "k3s_node" {
  source = "../../modules/vm"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_id       = 1010
  name        = "k3s-server"
  description = "The k3s server node, running both the control plane and a kubelet for pods hosting"

  environment = "prod"
  pool        = "prod"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr10"
  bridge_lan_network_ip = "10.42.10.1"

  vm_cpu_cores        = 4
  vm_dedicated_memory = 8192
  vm_floating_memory  = 0

  vm_params = {
    address   = var.vm_address
    disk_size = 50
    dns       = "10.42.1.2"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }

  custom_python = {
    enabled = true
  }
}
