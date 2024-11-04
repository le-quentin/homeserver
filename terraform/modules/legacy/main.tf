terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

# TODO split in several modules

###################################### Networks

variable "environment" {
  type = string
  description = "The deployment environment"
}

variable "node_name" {
  type = string
  description = "Name of the node where all the resources will be"
}

variable "pool" {
  type = string
  description = "Name of the pool where all the resources will be"
}

variable "bridge_lan_interface" {
  type        = string
  description = "The name of the network interface for the global bridge LAN"
}

variable "bridge_lan_network_ip" {
  type        = string
  description = "The ip address of the network for the the global bridge LAN"
}

variable "bridge_management_lan_interface" {
  type        = string
  description = "The name of the network interface for the management bridge LAN"
}

variable "bridge_management_lan_network_ip" {
  type        = string
  description = "The ip address of the network interface for the management bridge LAN"
}

resource "proxmox_virtual_environment_pool" "pool" {
  comment = "Staging environment pool"
  pool_id = var.pool
}

resource "proxmox_virtual_environment_network_linux_bridge" "bridge_lan_interface" {
  # depends_on = [
  #   proxmox_virtual_environment_network_linux_vlan.vlan99
  # ]

  node_name = var.node_name
  name      = var.bridge_lan_interface
  address = "${var.bridge_lan_network_ip}/24"
  comment   = "The global LAN for the ${var.environment} env"

  vlan_aware = true

  ports = [
    # Network (or VLAN) interfaces to attach to the bridge, specified by their interface name
    # (e.g. "ens18.99" for VLAN 99 on interface ens18).
    # For VLAN interfaces with custom names, use the interface name without the VLAN tag, e.g. "vlan_lab"
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "bridge_management_lan_interface" {
  # depends_on = [
  #   proxmox_virtual_environment_network_linux_vlan.vlan99
  # ]

  node_name = var.node_name
  name      = var.bridge_management_lan_interface
  address = "${var.bridge_management_lan_network_ip}/24"
  comment   = "The management LAN for the ${var.environment} env"

  vlan_aware = true

  ports = [
    # Network (or VLAN) interfaces to attach to the bridge, specified by their interface name
    # (e.g. "ens18.99" for VLAN 99 on interface ens18).
    # For VLAN interfaces with custom names, use the interface name without the VLAN tag, e.g. "vlan_lab"
  ]
}

###################################### VMs

variable "images" {
  description = "Object containing the various images availables for VM creation"
}

variable "disk_storage" {
  type        = string
  description = "Proxmox storage space for actual data (VM disks/containers volumes)"
}

variable "legacy_homeserver_vm" {
  type = object({
    address = string
    user = object({
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
  vm_id = 1801

  initialization {
    # do not use this in production, configure your own ssh key instead!
    user_account {
      username = var.legacy_homeserver_vm.user.username
      password = var.legacy_homeserver_vm.user.password
    }
    ip_config {
      ipv4 {
        address = var.legacy_homeserver_vm.address
        gateway = var.bridge_lan_network_ip
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

  network_device {
    bridge  = var.bridge_lan_interface
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
    floating  = 2048 # set equal to dedicated to enable ballooning
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  # startup {
  #   order      = "3"
  #   up_delay   = "60"
  #   down_delay = "60"
  # }

}

variable "opnsense_vm" {
  type = object({
    template_id = number
    address = string
  })
  description = "Opensense VM"
}

resource "proxmox_virtual_environment_vm" "opnsense_vm" {
  name        = "opnsense"
  node_name   = var.node_name
  description = "Opnsense firewall, managing the whole internal LAN: VLANs, routing and interaction with the outside world"

  pool_id = var.pool
  vm_id = 1001

  clone {
    vm_id = var.opnsense_vm.template_id
    full = false
  }

  network_device {
    bridge  = "vmbr0"
  }

  network_device {
    bridge  = var.bridge_management_lan_interface
  }

  network_device {
    bridge  = var.bridge_lan_interface
  }

  cpu {
    cores = 1
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = 1024
    floating  = 1024 # set equal to dedicated to enable ballooning
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

}
