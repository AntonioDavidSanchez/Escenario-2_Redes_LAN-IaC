# modules/vm/main.tf
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.1"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.vm_description
  node_name   = var.node_name
  vm_id       = var.vm_id
  tags        = var.vm_tags


  network_device {
    bridge = var.network_bridge0
  }

  network_device {
    bridge = var.network_bridge1
  }

  initialization {
    dns {
      servers = var.dns_servers
    }
    ip_config {
      ipv4 {
        address = var.ipv4_address0
        gateway = var.ipv4_gateway0
      }
    }
    ip_config{ 
      ipv4 {
        address = var.ipv4_address1
        gateway = var.ipv4_gateway1
      }
    }
  }

  clone {
    vm_id = var.clone_vm_id
    full  = var.clone_full
}
}

output "ipv4_address0" {
  value       = proxmox_virtual_environment_vm.vm.initialization[0].ip_config[0].ipv4[0].address
}

output "ipv4_address1" {
  value       = proxmox_virtual_environment_vm.vm.initialization[0].ip_config[1].ipv4[0].address
}

