terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

resource "proxmox_virtual_environment_download_file" "debian_12_raw_img" {
  content_type = "iso"
  datastore_id = var.img_storage
  file_name    = "debian-12-generic-amd64.img" #auto generated from url if not specified
  node_name    = var.node_name
  url          = var.debian_12_raw_img_url
}
