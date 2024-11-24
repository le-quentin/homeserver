variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "pool" {
  type        = string
  description = "Name of the pool where all the resources will be"
}

##### Variables with defaults

variable "icmp_enabled" {
  type        = string
  description = "Does the icmp security group actually open icmp"
  default = false
}

