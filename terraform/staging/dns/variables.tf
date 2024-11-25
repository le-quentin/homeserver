variable "dns_vm_address" {
  type        = string
  description = "Address of DNS VM"
  sensitive   = true
}

variable "dns_vm_ssh_key" {
  type        = string
  description = "Public key for SSH connection to DNS VM"
  sensitive   = true
}

variable "dns_vm_username" {
  type        = string
  description = "Username of DNS VM"
  sensitive   = true
}
