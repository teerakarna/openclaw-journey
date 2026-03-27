terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_url
  insecure = var.proxmox_tls_insecure
}

# Upload the cloud-init user-data snippet to Proxmox local storage
resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/cloud-init/user-data.yaml.tpl", {
      hostname   = var.vm_name
      ssh_pubkey = var.ssh_public_key
    })
    file_name = "openclaw-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "openclaw" {
  name      = var.vm_name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.disk_size_gb
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_prefix_length}"
        gateway = var.gateway
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  lifecycle {
    # Prevent re-cloning if the cloud-init file is recreated
    ignore_changes = [initialization[0].user_data_file_id]
  }
}
