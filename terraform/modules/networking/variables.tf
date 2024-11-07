variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "pool" {
  type        = string
  description = "Name of the pool where all the resources will be"
}

variable "bridge_lan_name" {
  type        = string
  description = "The name of the network interface for the global bridge LAN"
}

variable "bridge_lan_cidr_ip" {
  type        = string
  description = "The ip address of the network for the the global bridge LAN"
}

variable "bridge_mgtlan_name" {
  type        = string
  description = "The name of the network interface for the management bridge LAN"
}

variable "bridge_mgtlan_cidr_ip" {
  type        = string
  description = "The ip address of the network interface for the management bridge LAN"
}

##### Variables with defaults

variable "node_name" {
  type        = string
  description = "Name of the node where all the resources will be"
  default     = "beelink"
}

