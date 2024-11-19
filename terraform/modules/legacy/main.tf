terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

variable "legacy_homeserver_vm" {
  type = object({
    address = string
    user = object({
      ssh_key  = string
      username = string
    })
  })
  description = "Legacy VM (containing all containers in a single host, as it was on the Pi)"
}

resource "proxmox_virtual_environment_file" "cloudinit_user" {
  content_type = "snippets"
  # TODO automate the creation of the snippets data folder on proxmox (via ansible=>conf file?)
  datastore_id = "snippets"
  node_name    = var.node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    users:
      - name: ${var.legacy_homeserver_vm.user.username}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.legacy_homeserver_vm.user.ssh_key}
        sudo: ALL=(ALL) NOPASSWD:ALL
    # This could add the qemu guest agent
    runcmd:
        - apt update
        - apt install -y qemu-guest-agent net-tools
        - timedatectl set-timezone America/Toronto
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
        - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "cloudinit_user.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "legacy_homeserver_vm" {
  name        = "legacy-homeserver"
  node_name   = var.node_name
  description = "All the containers on one host, as it was before getting proxmox"

  pool_id = var.pool
  vm_id   = var.vm_ids_offset + 801

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloudinit_user.id

    ip_config {
      ipv4 {
        address = var.legacy_homeserver_vm.address
        gateway = var.legacy_vlan_network_ip
      }
    }
  }

  disk {
    datastore_id = var.disk_storage
    file_id      = var.images.debian
    interface    = "scsi0"
    size         = 20
  }

  usb {
    host = var.zigbee_dongle_id
  }

  # Legacy VLAN
  network_device {
    bridge  = var.bridge_lan_interface
    vlan_id = 200
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
    enabled = true
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  # stop_on_destroy = true

}
