# This file provisions my proxmox homeserver
# Proxmox is an hypervisor OS that is installed on my homeserver machine

# Terraform provider doc: https://registry.terraform.io/providers/Telmate/proxmox/2.9.14/docs
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

# Requires auth credentials in env vars, i.e. with PM_API_TOKEN_ID and PM_API_TOKEN_SECRET
provider "proxmox" {
  pm_api_url = "https://192.168.50.2:8006/api2/json"

  # Enable debug logs
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

resource "proxmox_vm_qemu" "test-terraform-vm" {
  name        = "test-terraform-vm"
  target_node = "piserv"
  iso         = "local:iso/alpine-standard-3.19.0-x86_64.iso"


  ### or for a Clone VM operation
  # clone = "template to clone"

  ### or for a PXE boot VM operation
  # pxe = true
  # boot = "net0;scsi0"
  # agent = 0
  
  network {
    bridge = "vmbr0"
    model = "virtio"
  }

  disk {
    # set disk size here. leave it small for testing because expanding the disk takes time.
    size = "10G"
    type = "scsi"
    storage = "local"
    ssd = 1
    #iothread = 1
  }
  
  # cd reader as a scsi drive, ide not support by raspberry pi
  disk {
    size = "1G"
    type = "scsi"
    storage = "local"
    media = "cdrom"
    volume = "local:iso/alpine-standard-3.19.0-x86_64.iso"
  }
}
