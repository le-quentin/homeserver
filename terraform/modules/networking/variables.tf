variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "pool" {
  type        = string
  description = "Name of the pool where all the resources will be"
}

variable "networking_lan_name" {
  type        = string
  description = "The name of the network interface for the network apps (DNS, Router, DHCP...) bridge LAN"
}

variable "networking_lan_cidr_ip" {
  type        = string
  description = "The ip address of the network for the the network apps (DNS, Router, DHCP...) bridge LAN"
}

variable "k3s_lan_name" {
  type        = string
  description = "The name of the network interface for the k3s bridge LAN"
}

variable "k3s_lan_cidr_ip" {
  type        = string
  description = "The ip address of the network for the the k3s bridge LAN"
}

##### Variables with defaults

variable "node_name" {
  type        = string
  description = "Name of the node where all the resources will be"
  default     = "beelink"
}

