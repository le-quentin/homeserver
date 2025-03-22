module "k3s_node" {
  source = "../../modules/vm"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_id       = 2010
  name        = "k3s-server"
  description = "The k3s server node, running both the control plane and a kubelet for pods hosting"

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1010"
  bridge_lan_network_ip = "10.142.10.1"

  # usb_mappings = [
  #   { device_id = "toto" }
  # ]

  vm_cpu_cores        = 2
  vm_dedicated_memory = 4096
  vm_floating_memory  = 0 # Disable ballooning because k3s doesn't like swapping

  vm_params = {
    address   = var.vm_address
    disk_size = 30
    dns       = "10.142.1.2"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }

  custom_python = {
    enabled = true
  }
}
