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

variable "vm_id" {
  type = number
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "dedicated_memory" {
  type    = number
  default = 2048
}

variable "floating_memory" {
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

variable "name" {
  type        = string
  description = "Name of the lxc as it will appear in Proxmox"
  default     = "k3s-node"
}

variable "description" {
  type        = string
  description = "Description of the lxc as it will appear in Proxmox"
  default     = "A k3s node (agent or server) machine"
}

variable "disk_storage" {
  type        = string
  description = "Proxmox storage space for actual data (lxc disks/containers volumes)"
  default     = "local-lvm"
}

variable "privileged" {
  type        = bool
  description = "Is the container running in privileged mode ? (dangerous)"
  default     = false
}

variable "nesting" {
  type        = bool
  description = "Is nesting feature enabled ? (dangerous++)"
  default     = false
}

variable "firewall_enabled" {
  type = bool
  default = true
}


