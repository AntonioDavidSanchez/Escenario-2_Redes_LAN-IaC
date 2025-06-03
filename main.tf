# main.tf

resource "time_static" "deployment_start" {
  triggers = {
    always_run = timestamp()
  }
}


module "ubuntu_server" {
  source = "./modules/vm"

  vm_name        = "UbuntuServer"
  vm_description = "Ubuntu Server con Wazuh Indexer, Server y Dashboard"
  node_name      = "kvm1"
  vm_id          = 850
  vm_tags        = ["UbuntuServer"]
  network_bridge0 = "vmbr0"
  network_bridge1 = "vmbr1"
  dns_servers = ["8.8.8.8"]
  ipv4_address0   = "192.168.10.50/24"
  ipv4_address1   = "10.100.1.2/24"
  ipv4_gateway0   = "192.168.10.6"
  ipv4_gateway1   = "10.100.1.1"
  clone_vm_id    = 111
  clone_full = true
}


module "ubuntu_server_2" {
  source = "./modules/vm"

  vm_name        = "UbuntuServer1"
  vm_description = "Ubuntu Server con Suricata, Wazuh Agent y Atomic Red Team"
  node_name      = "kvm1"
  vm_id          = 853
  vm_tags        = ["UbuntuServer1"]

  network_bridge0 = "vmbr0"
  network_bridge1 = "vmbr1"
  dns_servers = ["8.8.8.8"]
  ipv4_address0   = "192.168.10.53/24"
  ipv4_address1   = ""
  ipv4_gateway0   = "192.168.10.6"
  ipv4_gateway1   = ""
  clone_vm_id    = 111
  clone_full = true
  depends_on = [module.ubuntu_server]
}

module "vyos_router" {
  source = "./modules/vm"

  vm_name        = "VyOsRouter"
  vm_description = "VyOSRouter para separar dos redes LAN"
  node_name      = "kvm1"

  vm_id          = 854

  vm_tags        = ["VyOsRouter"]
 
  network_bridge0 = "vmbr0"
  network_bridge1 = "vmbr1"
  dns_servers = ["8.8.8.8"]
  ipv4_address0   = "10.200.1.1/24"
  ipv4_address1   = "10.100.1.1/24"
  ipv4_gateway0   = ""
  ipv4_gateway1   = ""
  clone_vm_id    = 104
  clone_full = true
}


module "kali_linux" {
  source = "./modules/vm"

  vm_name        = "KaliLinux"
  vm_description = "Kali Linux"
  node_name      = "kvm1"
  vm_id          = 851
  vm_tags        = ["KaliLinux"]

  network_bridge0 = "vmbr0"
  network_bridge1 = "vmbr1"

  dns_servers = ["8.8.8.8"]
  ipv4_address0   = "10.200.1.3/24"
  ipv4_address1   = ""
  ipv4_gateway0   = "10.200.1.1"
  ipv4_gateway1   = ""
  clone_vm_id    = 106
  clone_full = true
  depends_on = [module.ubuntu_server_2]
}

module "windows_11" {
  source = "./modules/vm"

  vm_name        = "WindowsOS11"
  vm_description = "Windows 11 con Wazuh Agent y Atomic Red Team"
  node_name      = "kvm1"
  vm_id          = 852
  vm_tags        = ["WindowsOS11"]
  network_bridge0 = "vmbr0"
  network_bridge1 = "vmbr1"
  dns_servers = ["8.8.8.8"]
  ipv4_address0   = "192.168.10.52/24"
  ipv4_address1   = "10.100.1.3/24"
  ipv4_gateway0   = "192.168.10.6"
  ipv4_gateway1   = "10.100.1.1"
  clone_vm_id    = 102
  clone_full = true
  depends_on = [module.kali_linux]
}



# Instalación de Wazuh server, indexer y dashboard en la máquina Ubuntu Server
 resource "null_resource" "install_wazuh" {
  triggers = {
    always_run = "${timestamp()}"
  }
  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver
    password    = var.vm_password_ubuntuserver
    host = split("/", module.ubuntu_server.ipv4_address0)[0]
    port = 22
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y curl",
      "curl -sO https://packages.wazuh.com/4.5/wazuh-install.sh",
      "sudo -S bash ./wazuh-install.sh -a -i",
      "sudo ip route add 10.0.0.0/8 via 10.100.1.1"
    ]
  }
}

# Instalación del agente de Wazuh en la máquina Ubuntu Server
resource "null_resource" "install_wazuh_agent_ubuntuserver" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver
    password    = var.vm_password_ubuntuserver
    host = split("/", module.ubuntu_server_2.ipv4_address0)[0]
    port        = 22
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
  }

  provisioner "remote-exec" {
    inline = [
      "curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.5.4-1_amd64.deb && sudo WAZUH_MANAGER='${split("/", module.ubuntu_server.ipv4_address1)[0]}' WAZUH_AGENT_NAME='Ubuntu' dpkg -i ./wazuh-agent.deb",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wazuh-agent",
      "sudo systemctl start wazuh-agent"
    ]
  }
  depends_on = [null_resource.install_wazuh]
}

# Instalación del agente de Wazuh en la máquina Windows
resource "null_resource" "install_wazuh_agent_windows11" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type     = "ssh"
    user     = var.vm_user_windows11
    password = var.vm_password_windows11
    host     = split("/", module.windows_11.ipv4_address0)[0]
    port     = 22
    bastion_host     = var.bastion_host
    bastion_user     = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
    target_platform  = "windows"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -Command \"Invoke-WebRequest -Uri 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.5.4-1.msi' -OutFile $env:TEMP\\wazuh-agent.msi\"",
      "powershell -Command \"Start-Process msiexec.exe -ArgumentList '/i', $env:TEMP\\wazuh-agent.msi, '/qn', 'WAZUH_MANAGER=${split("/", module.ubuntu_server.ipv4_address1)[0]}', 'WAZUH_REGISTRATION_SERVER=${split("/", module.ubuntu_server.ipv4_address1)[0]}', 'WAZUH_AGENT_NAME=Windows', '/L*v', $env:TEMP\\wazuh_install.log -NoNewWindow -Wait\"",
      "powershell -Command \"if (Get-Service -Name 'Wazuh' -ErrorAction SilentlyContinue) { Start-Service 'Wazuh'; Write-Output 'Wazuh Agent iniciado.' } else { Write-Error 'ERROR: El servicio Wazuh no existe tras la instalación'; exit 1 }\""
    ]
  }
  depends_on = [
    module.windows_11, 
    null_resource.install_wazuh
  ]
}


# Instalación de Atomic Red Team en la máquina Windows
resource "null_resource" "install_atomic_red_team_windows11" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type     = "ssh"
    user     = var.vm_user_windows11
    password = var.vm_password_windows11
    host     = split("/", module.windows_11.ipv4_address0)[0]
    port     = 22
    bastion_host     = var.bastion_host
    bastion_user     = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
    target_platform  = "windows"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -Command \"Disable-NetAdapter -Name 'Ethernet 2' -Confirm:$false\"",  
      "powershell -Command \"Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile 'Sysmon.zip'\"",
      "powershell -Command \"Expand-Archive -Path Sysmon.zip -DestinationPath C:\\Sysmon -Force\"",
      "powershell -Command \"New-Item -Path C:\\Sysmon\\sysmonconfig.xml -ItemType File -Force\"",
      "powershell -Command \"Invoke-WebRequest -Uri 'https://wazuh.com/resources/blog/emulation-of-attack-techniques-and-detection-with-wazuh/sysmonconfig.xml' -OutFile C:\\Sysmon\\sysmonconfig.xml\"",
      "powershell -Command \"Start-Process powershell -Verb RunAs\"",
      "powershell -Command \"& 'C:\\sysmon\\sysmon64.exe' -accepteula -i 'C:\\Sysmon\\sysmonconfig.xml'\"",
      "powershell -Command \"IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)\"",
      "powershell -Command \"Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force\"",
      "powershell -Command \"Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force\"",
      "powershell -Command \"IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); Install-AtomicRedTeam -getAtomics\"",
      "powershell -Command \"Import-Module 'C:\\AtomicRedTeam\\invoke-atomicredteam\\Invoke-AtomicRedTeam.psd1' -Force\"",
      "powershell -Command \"Enable-NetAdapter -Name 'Ethernet 2' -Confirm:$false\"",
      "powershell -Command \"Disable-NetAdapter -Name 'Ethernet' -Confirm:$false\"; powershell -Command \"Restart-Service wazuh\""
    ]
   on_failure = continue
  }

  depends_on = [
    null_resource.install_wazuh_agent_windows11
  ]
}

# Instalación de Atomic Red Team en la máquina Ubuntu Server
resource "null_resource" "install_atomic_red_team_ubuntuserver" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver
    password    = var.vm_password_ubuntuserver
    host = split("/", module.ubuntu_server_2.ipv4_address0)[0]
    port        = 22
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
  }

  provisioner "remote-exec" {
    inline = [
     "sudo ip link set eth1 down",
     "sudo apt-get update",
     "sudo apt-get install -y wget apt-transport-https software-properties-common git",
     "wget -O packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb && sudo dpkg -i packages-microsoft-prod.deb",
     "sudo apt-get update",
     "sudo apt-get install -y powershell",
     "pwsh -Command \"git clone 'https://github.com/redcanaryco/atomic-red-team.git'\"",
     "pwsh -Command \"IEX (Invoke-WebRequest 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); Install-AtomicRedTeam -getAtomics -Force\"",
     "pwsh -Command \"Import-Module /home/ubuntuserver/AtomicRedTeam/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1 -Force\""
    ]
  }
  depends_on = [null_resource.install_wazuh_agent_ubuntuserver]
}

# Instalación de Suricata en la máquina Ubuntu Server
resource "null_resource" "install_suricata" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver
    password    = var.vm_password_ubuntuserver
    host = split("/", module.ubuntu_server_2.ipv4_address0)[0]
    port        = 22
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo add-apt-repository -y ppa:oisf/suricata-stable",
      "sudo apt-get update",
      "sudo apt-get install suricata -y",
      "cd /tmp/ && curl -LO https://rules.emergingthreats.net/open/suricata-6.0.8/emerging.rules.tar.gz",
      "sudo tar -xvzf emerging.rules.tar.gz && sudo mv rules/*.rules /etc/suricata/rules/",
      "sudo chmod 640 /etc/suricata/rules/*.rules",
      "sudo ip route del default via 192.168.10.6; sudo ip address del 192.168.10.53/24 dev eth0; sudo ip address add 10.200.1.2/24 dev eth0; sudo ip route add 10.0.0.0/8 via 10.200.1.1; sudo systemctl restart wazuh-agent"
    ]
    on_failure = continue
  }
  depends_on = [null_resource.install_atomic_red_team_ubuntuserver]
}

# Generación de una notificación cuando finalice el despligue a partir de un bot de Telegram creado previamente
resource "null_resource" "telegram_notification" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    module.vyos_router,
    module.kali_linux,
    null_resource.install_suricata,
    null_resource.install_atomic_red_team_windows11,
    time_static.deployment_start
  ]

  provisioner "local-exec" {
    command = <<EOT
      $ErrorActionPreference = "Stop"
      try {
        $startTime = [datetime]::ParseExact("${time_static.deployment_start.rfc3339}", "yyyy-MM-ddTHH:mm:ssZ", $null)
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $durationString = "{0:D2}h:{1:D2}m:{2:D2}s" -f $duration.Hours, $duration.Minutes, $duration.Seconds
        $message = "DESPLIEGUE DEL ESCENARIO CON 2 REDES LAN COMPLETADO A LAS: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')). DURACIÓN DEL DESPLIEGUE: $durationString"
        $uri = "https://api.telegram.org/bot${var.telegram_bot_token}/sendMessage"
        $body = @{
          chat_id = "${var.telegram_chat_id}"
          text = $message
        }
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body
        Write-Host "Mensaje enviado a Telegram: $message"
        Write-Host "Respuesta de Telegram: $($response | ConvertTo-Json -Depth 1)"
      }
      catch {
        Write-Host "Error al enviar mensaje a Telegram: $_"
        exit 1
      }
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}
