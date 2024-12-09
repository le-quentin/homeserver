module "nfs_server" {
  source = "../../modules/lxc_container"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  images = {
    debian = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  }

  ids_offset  = 2000
  name        = "nfs-server"
  description = "NFS server, whose primary function is storing K3S cluster Filesystem volumes"

  environment = "staging"
  pool        = "staging"

  //TODO use local datasource to communicate module outputs (https://developer.hashicorp.com/terraform/language/backend/local)
  bridge_lan_interface  = "vmbr1010"
  bridge_lan_network_ip = "10.142.10.1"

  lxc_params = {
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
