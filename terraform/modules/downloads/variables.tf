variable "node_name" {
  type        = string
  description = "The Proxmox node where the images will be stored"
  default     = "beelink"
}

variable "img_storage" {
  type        = string
  description = "The Proxmox storage when the images will be stored"
  default     = "local"
}

variable "debian_12_raw_img_url" {
  type        = string
  description = "The url address where to pull debian 12 image"
  default     = "https://cloud.debian.org/images/cloud/bookworm/20241004-1890/debian-12-generic-amd64-20241004-1890.raw"
}

