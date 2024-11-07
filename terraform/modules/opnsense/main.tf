terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

resource "proxmox_virtual_environment_vm" "opnsense_vm" {
  name        = "opnsense"
  node_name   = var.node_name
  description = "Opnsense firewall, managing the whole internal LAN: VLANs, routing and interaction with the outside world"

  pool_id = var.pool
  vm_id   = var.vm_ids_offset + 1

  clone {
    vm_id = var.opnsense_vm_template_id
    full  = false
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = var.bridge_management_lan_interface
  }

  network_device {
    bridge = var.bridge_lan_interface
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
