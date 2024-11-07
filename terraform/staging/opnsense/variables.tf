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
