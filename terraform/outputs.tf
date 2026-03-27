output "vm_ip" {
  description = "IP address of the openclaw VM"
  value       = var.vm_ip
}

output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.openclaw.vm_id
}

output "ssh_connect" {
  description = "SSH connection string"
  value       = "ssh openclaw@${var.vm_ip}"
}
