variable "vm_address" {
  type        = string
  description = "Address of the VM/LXC"
  sensitive   = true
}

variable "vm_ssh_key" {
  type        = string
  description = "Public key for SSH connection to the VM/LXC"
  sensitive   = true
}

variable "vm_username" {
  type        = string
  description = "Username of the VM/LXC"
  sensitive   = true
}
