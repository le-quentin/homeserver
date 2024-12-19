terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

variable "vm_params" {
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

variable "custom_python" {
  type = object({
    enabled   = optional(bool, false)
    venv_name = optional(string, "python")
  })
  default = {
  }
}

locals {
  vm_id    = var.vm_id
  home_dir = "/home/${var.vm_params.user.username}"
  python_venv_cmds = var.custom_python.enabled ? [
    "apt install -y python3-venv",
    "sudo -u ${var.vm_params.user.username} mkdir ${local.home_dir}/python",
    "sudo -u ${var.vm_params.user.username} python3 -m venv ${local.home_dir}/python/ansible_venv"
  ] : []
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
      - name: ${var.vm_params.user.username}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.vm_params.user.ssh_key}
        sudo: ALL=(ALL) NOPASSWD:ALL
    # add the qemu guest agent
    runcmd:
        - apt update
        - apt install -y qemu-guest-agent net-tools
        - timedatectl set-timezone Europe/Paris
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent

%{for cmd in local.python_venv_cmds}
        - ${cmd}
%{endfor}

        - echo "done" > /tmp/cloud-config.done

    EOF

    file_name = "cloudinit_user_${local.vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  node_name   = var.node_name
  name        = var.name
  description = var.description

  pool_id = var.pool
  vm_id   = local.vm_id

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloudinit_user.id

    ip_config {
      ipv4 {
        address = var.vm_params.address
        gateway = var.bridge_lan_network_ip
      }
    }

    dns {
      domain = "bonnet-lan"
      servers = [
        var.vm_params.dns,
        "1.1.1.1"
      ]
    }

  }

  disk {
    datastore_id = var.disk_storage
    file_id      = var.images.debian
    interface    = "scsi0"
    size         = var.vm_params.disk_size
  }

  dynamic "usb" {
    for_each = var.usb_mappings
    content {
      host = usb.value.device_id
    }
  }

  network_device {
    bridge   = var.bridge_lan_interface
    firewall = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.vm_cpu_cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = var.vm_dedicated_memory
    floating  = var.vm_floating_memory # set equal to dedicated to enable ballooning
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

}

resource "proxmox_virtual_environment_firewall_options" "vm_params_firewall_options" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  enabled       = false # Disabled for now, to not make k3s setup more complex than it already is
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "vm_firewall_rules" {
  depends_on = [
    proxmox_virtual_environment_vm.vm
  ]

  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  rule {
    security_group = "${var.environment}-ssh"
    iface          = "net0"
  }

  rule {
    security_group = "${var.environment}-http"
    iface          = "net0"
  }

  rule {
    security_group = "${var.environment}-https"
    iface          = "net0"
  }

  rule {
    security_group = "${var.environment}-icmp"
    iface          = "net0"
  }

}
