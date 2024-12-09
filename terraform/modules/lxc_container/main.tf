terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

locals {
  lxc_id = var.ids_offset + 20
}

variable "lxc_params" {
  type = object({
    address   = string
    dns       = string
    disk_size = number
    user = object({
      ssh_key  = string
      username = string
    })
  })
}

resource "proxmox_virtual_environment_container" "lxc" {
  node_name   = var.node_name
  description = var.description

  pool_id = var.pool
  vm_id   = local.lxc_id

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.lxc_params.address
        gateway = var.bridge_lan_network_ip
      }
    }

    user_account {
      keys = [
        var.lxc_params.user.ssh_key
      ]
    }

    dns {
      domain = "bonnet-lan"
      servers = [
        var.lxc_params.dns,
        "1.1.1.1"
      ]
    }

  }

  network_interface {
    name     = "eth0"
    bridge   = var.bridge_lan_interface
    firewall = true
  }

  disk {
    datastore_id = var.disk_storage
    size         = var.lxc_params.disk_size
  }

  operating_system {
    template_file_id = var.images.debian
    type             = "debian"
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.dedicated_memory
    swap      = var.floating_memory
  }

}
