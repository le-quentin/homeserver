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
  default = 2048
}

variable "vm_floating_memory" {
  type        = number
  description = "Set equal to dedicated to enable ballooning"
  default     = 2048
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

variable "vm_name" {
  type        = string
  description = "Name of the VM as it will appear in Proxmox"
  default     = "k3s-node"
}

variable "vm_description" {
  type        = string
  description = "Description of the VM as it will appear in Proxmox"
  default     = "A k3s node (agent or server) machine"
}

variable "disk_storage" {
  type        = string
  description = "Proxmox storage space for actual data (VM disks/containers volumes)"
  default     = "local-lvm"
}

variable "usb_mappings" {
  type        = list(any)
  description = "Id of and usb device (int the \"<bus>-<device>\" format) to passthrough to the VM"
  default     = []
}

