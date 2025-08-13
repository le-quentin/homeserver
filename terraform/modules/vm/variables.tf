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

variable "name" {
  type        = string
  description = "Name of the VM as it will appear in Proxmox"
}

variable "description" {
  type        = string
  description = "Description of the VM as it will appear in Proxmox"
}

variable "vm_id" {
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
  default     = 0
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

variable "usb_mappings" {
  type        = list(any)
  description = "Id and options of usb devices (in the \"<bus>-<device>\" format) to passthrough to the VM"
  default     = []
}

variable "disks" {
  type        = list(any)
  description = "Additional disks for the VM"
  default     = []
}

variable "pci_mappings" {
  type        = list(any)
  description = "Ids of pci devices to passthrough to the VM. hostpci_id in the hostpciX format, from the proxmox hostpci list"
  default     = []
}

