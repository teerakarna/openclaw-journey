variable "proxmox_url" {
  description = "Proxmox API URL, e.g. https://192.168.1.100:8006/"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name to deploy on"
  type        = string
  default     = "pve"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (set true for self-signed certs)"
  type        = bool
  default     = true
}

variable "vm_name" {
  description = "VM hostname"
  type        = string
  default     = "openclaw"
}

variable "vm_id" {
  description = "Proxmox VM ID for the new VM"
  type        = number
  default     = 200
}

variable "template_vm_id" {
  description = "Proxmox VM ID of the Debian 12 cloud-init template"
  type        = number
  default     = 9000
}

variable "cpu_cores" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 20
}

variable "storage_pool" {
  description = "Proxmox storage pool for the VM disk"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip" {
  description = "Static IP address to assign to the VM"
  type        = string
}

variable "vm_prefix_length" {
  description = "Network prefix length (e.g. 24 for /24)"
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Default gateway for the VM"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject for the openclaw user"
  type        = string
}
