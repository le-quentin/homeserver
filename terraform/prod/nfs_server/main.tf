module "nfs_server" {
  source = "../../modules/vm"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:iso/debian-12-generic-amd64.img"
  }

  vm_id       = 1020
  name        = "nfs-server"
  description = "NFS server, whose primary function is storing K3S cluster Filesystem volumes, and backups"

  environment = "prod"
  pool        = "prod"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr10"
  bridge_lan_network_ip = "10.42.10.1"

  vm_cpu_cores        = 4
  vm_dedicated_memory = 4096
  vm_floating_memory  = 4096

  disks = [
    {
      size = 100
    }
  ]
  vm_params = {
    address   = var.vm_address
    disk_size = 10
    dns       = "10.42.1.2"
    user = {
      ssh_key  = var.vm_ssh_key
      username = var.vm_username
    }
  }
}
# TODO add firewall for security
