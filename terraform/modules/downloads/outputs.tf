output "images" {
  description = "All the images pulled"
  value = {
    storage = var.img_storage
    debian = proxmox_virtual_environment_download_file.debian_12_raw_img.id
  }
}
