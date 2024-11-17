variable "legacy_homeserver_address" {
  type        = string
  description = "Address of legacy homeserver"
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
