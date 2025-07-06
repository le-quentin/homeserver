terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

variable "proxmox_endpoint" {
  type        = string
  description = "Complete URL of the proxmox server, with port number"
  sensitive   = true
}

variable "proxmox_username" {
  type        = string
  description = "Username with admin access to Proxmox"
  sensitive   = true
}

variable "proxmox_password" {
  type        = string
  description = "Password for the Proxmox user"
  sensitive   = true
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password

  # because self-signed TLS certificate is in use
  insecure = true

  ssh {
    agent = true
    # TODO: uncomment and configure if using api_token instead of password
    # username = "root"
  }
}
