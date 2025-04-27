variable "vm_address" {
  type        = string
  description = "IP address of VM"
  sensitive   = true
}

variable "vm_ssh_key" {
  type        = string
  description = "Public key for SSH connection to VM"
  sensitive   = true
}

variable "vm_username" {
  type        = string
  description = "Username for VM OS"
  sensitive   = true
}
