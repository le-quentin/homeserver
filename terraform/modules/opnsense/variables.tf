variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "pool" {
  type        = string
  description = "Name of the pool where all the resources will be"
}

variable "opnsense_vm_template_id" {
  type        = number
  description = "The template to create the Opnsense VM from"
}

variable "bridge_lan_interface" {
  type        = string
  description = "The name of the network interface for the global bridge LAN"
}

variable "bridge_lan_network_ip" {
  type        = string
  description = "The ip address of the network for the the global bridge LAN"
}

variable "bridge_management_lan_interface" {
  type        = string
  description = "The name of the network interface for the management bridge LAN"
}

variable "bridge_management_lan_network_ip" {
  type        = string
  description = "The ip address of the network interface for the management bridge LAN"
}

variable "legacy_vlan_network_ip" {
  type        = string
  description = "The ip address of the legacy VLAN"
}

variable "sshmgt_vlan_network_ip" {
  type        = string
  description = "The ip address of the SSH management VLAN"
}

variable "vm_ids_offset" {
  type = number
}

variable "vm_cpu_cores" {
  type    = number
  default = 2
}

variable "vm_cpu_dedicated_memory" {
  type    = number
  default = 2048
}

variable "vm_cpu_floating_memory" {
  type        = number
  description = "Set equal to dedicated to enable ballooning"
  default     = 2048
}

##### Variables with defaults

variable "node_name" {
  type        = string
  description = "Name of the node where all the resources will be"
  default     = "beelink"
}

