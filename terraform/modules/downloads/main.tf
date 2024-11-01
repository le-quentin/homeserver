terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

variable "node_name" {
  type = string
  description = "The Proxmox node where the images will be stored"
}

variable "img_storage" {
  type        = string
  description = "The Proxmox storage when the images will be stored"
}

variable "debian_12_raw_img_url" {
  type        = string
  description = "The url address where to pull debian 12 image"
}

resource "proxmox_virtual_environment_download_file" "debian_12_raw_img" {
  content_type = "iso"
  datastore_id = var.img_storage
  file_name    = "debian-12-generic-amd64.img" #auto generated from url if not specified
  node_name    = var.node_name
  url          = var.debian_12_raw_img_url
}
