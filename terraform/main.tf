variable "environment" {
  type        = string
  description = "The current environment"
}

variable "pool" {
  type        = string
  description = "The resources pool for this environment"
}

variable "node_name" {
  type        = string
  description = "The name of the node (physical server) on which we'll deploy"
}

variable "legacy_homeserver_address" {
  type        = string
  description = "Address of legacy homeserver"
  sensitive   = true
}

variable "legacy_homeserver_sshmgt_address" {
  type        = string
  description = "Address of legacy homeserver (SSH)"
  sensitive   = true
}

variable "legacy_homeserver_ssh_key" {
  type        = string
  description = "Public key for SSH connection to legacy VM"
  sensitive   = true
}

variable "legacy_homeserver_username" {
  type        = string
  description = "Username of legacy homeserver"
  sensitive   = true
}

variable "legacy_homeserver_password" {
  type        = string
  description = "Password of legacy homeserver"
  sensitive   = true
}

variable "opnsense_template_id" {
  type        = number
  description = "Id of the template Opnsense VM will be cloned from"
  sensitive   = true
}

variable "opnsense_address" {
  type        = string
  description = "Address of opnsense"
  sensitive   = true
}

variable "opnsense_username" {
  type        = string
  description = "Username of opnsense"
  sensitive   = true
}

variable "opnsense_password" {
  type        = string
  description = "Password of opnsense"
  sensitive   = true
}

module "downloads" {
  source = "./modules/downloads"

  node_name = var.node_name

  img_storage           = "local"
  debian_12_raw_img_url = "https://cloud.debian.org/images/cloud/bookworm/20241004-1890/debian-12-generic-amd64-20241004-1890.raw"
  # debian_12_raw_img_url = "https://cloud.debian.org/images/cloud/bookworm/20241004-1890/debian-12-generic-amd64-20241004-1890.tar.xz"
}

module "legacy" {
  source = "./modules/legacy"

  environment = var.environment
  pool        = var.pool
  node_name   = var.node_name

  images                           = module.downloads.images
  bridge_lan_interface             = "vmbr1001"
  bridge_lan_network_ip            = "10.142.1.100"
  bridge_management_lan_interface  = "vmbr1100"
  bridge_management_lan_network_ip = "10.143.1.100"
  legacy_vlan_network_ip           = "10.142.200.1"
  sshmgt_vlan_network_ip           = "10.142.254.1"

  disk_storage = "local-lvm"

  legacy_homeserver_vm = {
    address = var.legacy_homeserver_address
    sshmgt_address = var.legacy_homeserver_sshmgt_address
    user = {
      ssh_key  = var.legacy_homeserver_ssh_key
      username = var.legacy_homeserver_username
      password = var.legacy_homeserver_password
    }
  }

  opnsense_vm = {
    template_id = var.opnsense_template_id
    address     = var.opnsense_address
  }
}
