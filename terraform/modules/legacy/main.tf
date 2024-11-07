terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

###################################### VMs

variable "legacy_homeserver_vm" {
  type = object({
    address        = string
    sshmgt_address = string
    user = object({
      ssh_key  = string
      username = string
      password = string
    })
  })
  description = "Legacy VM (containing all containers in a single host, as it was on the Pi)"
}

resource "proxmox_virtual_environment_vm" "legacy_homeserver_vm" {
  name        = "legacy-homeserver"
  node_name   = var.node_name
  description = "All the containers on one host, as it was before getting proxmox"

  pool_id = var.pool
  vm_id   = var.vm_ids_offset + 801

  initialization {
    user_account {
      keys = [var.legacy_homeserver_vm.user.ssh_key]
      # do not use this in production, configure your own ssh key instead!
      username = var.legacy_homeserver_vm.user.username
      password = var.legacy_homeserver_vm.user.password
    }
    ip_config {
      ipv4 {
        address = var.legacy_homeserver_vm.address
        gateway = var.legacy_vlan_network_ip
      }
    }
    ip_config {
      ipv4 {
        address = var.legacy_homeserver_vm.sshmgt_address
        gateway = var.sshmgt_vlan_network_ip
      }
    }
  }

  disk {
    datastore_id = var.disk_storage
    file_id      = var.images.debian
    # file_format = "raw"
    # file_id      = "disk_debian-12-generic-amd64.qcow2.img"
    interface = "scsi0"
    # iothread  = true
  }

  # disk {
  #   datastore_id = var.disk_storage
  #   interface    = "scsi0"
  #   iothread     = true
  # }

  # Legacy VLAN
  network_device {
    bridge  = var.bridge_lan_interface
    vlan_id = 200
  }

  # SSH management VLAN
  network_device {
    bridge  = var.bridge_lan_interface
    vlan_id = 254
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.vm_cpu_cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = var.vm_cpu_dedicated_memory
    floating  = var.vm_cpu_floating_memory # set equal to dedicated to enable ballooning
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

}
