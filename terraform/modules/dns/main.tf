terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

variable "dns_vm" {
  type = object({
    address      = string
    cidr_address = string
    disk_size    = number
    user = object({
      ssh_key  = string
      username = string
    })
  })
  description = "DNS VM"
}

resource "proxmox_virtual_environment_file" "dns_vm_cloudinit_user" {
  content_type = "snippets"
  # TODO automate the creation of the snippets data folder on proxmox (via ansible=>conf file?)
  datastore_id = "snippets"
  node_name    = var.node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    users:
      - name: ${var.dns_vm.user.username}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.dns_vm.user.ssh_key}
        sudo: ALL=(ALL) NOPASSWD:ALL
    # This could add the qemu guest agent
    runcmd:
        - apt update
        - apt install -y qemu-guest-agent net-tools
        - timedatectl set-timezone Europe/Paris
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
        - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "dns_vm_cloudinit_user.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "dns_vm" {
  name        = "adguard-dns"
  node_name   = var.node_name
  description = "DNS + ad-blocking"

  pool_id = var.pool
  vm_id   = var.vm_ids_offset + 1

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.dns_vm_cloudinit_user.id

    ip_config {
      ipv4 {
        address = var.dns_vm.cidr_address
        gateway = var.bridge_lan_network_ip
      }
    }

  }

  disk {
    datastore_id = var.disk_storage
    file_id      = var.images.debian
    interface    = "scsi0"
    size         = var.dns_vm.disk_size
    discard      = "on" # Very important, otherwise VM freed space is never freed on host and disk fills forever more
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
    type  = "host"
  }

  memory {
    dedicated = var.vm_dedicated_memory
    floating  = var.vm_floating_memory # set equal to dedicated to enable ballooning
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
  }
}

resource "proxmox_virtual_environment_firewall_options" "dns_vm_firewall_options" {
  depends_on = [proxmox_virtual_environment_vm.dns_vm]

  node_name = proxmox_virtual_environment_vm.dns_vm.node_name
  vm_id     = proxmox_virtual_environment_vm.dns_vm.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "dns_vm_firewall_rules" {
  depends_on = [
    proxmox_virtual_environment_vm.dns_vm
  ]

  node_name = proxmox_virtual_environment_vm.dns_vm.node_name
  vm_id     = proxmox_virtual_environment_vm.dns_vm.vm_id

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

  rule {
    security_group = "${var.environment}-dns"
    iface          = "net0"
  }

}

resource "proxmox_virtual_environment_dns" "first_node_dns_configuration" {
  count      = var.main_dns == true ? 1 : 0
  depends_on = [proxmox_virtual_environment_vm.dns_vm]

  domain    = "bonnet-lan"
  node_name = var.node_name

  servers = [
    var.dns_vm.address,
    "8.8.4.4",
  ]
}
