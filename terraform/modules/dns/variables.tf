variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "pool" {
  type        = string
  description = "Name of the pool where all the resources will be"
}

variable "images" {
  description = "Object containing the various images availables for VM creation"
}

variable "vm_ids_offset" {
  type = number
}

variable "vm_cpu_cores" {
  type    = number
  default = 2
}

variable "vm_dedicated_memory" {
  type    = number
  default = 1024
}

variable "vm_floating_memory" {
  type        = number
  description = "Set equal to dedicated to enable ballooning"
  default     = 1024
}

variable "bridge_lan_interface" {
  type        = string
  description = "The name of the network interface for the global bridge LAN"
}

variable "bridge_lan_network_ip" {
  type        = string
  description = "The ip address of the network for the the global bridge LAN"
}

##### Variables with defaults

variable "node_name" {
  type        = string
  description = "Name of the node where all the resources will be"
  default     = "beelink"
}

variable "disk_storage" {
  type        = string
  description = "Proxmox storage space for actual data (VM disks/containers volumes)"
  default     = "local-lvm"
}

variable "main_dns" {
  type = bool
  description = "Should this be used as the primary Proxmox DNS"
  default = false
}
