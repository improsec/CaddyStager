#Deploy CS teamserver
# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "CADDY" {
    name     = "CADDY"
    location = var.AzureLocationNE

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create random password
resource "random_password" "CaddyAdminPassword" {
  length = 35
  special = true
  override_special = "_%@"
}

# Create virtual network
resource "azurerm_virtual_network" "CADDY-Network" {
    name                = "CADDY-VNet"
    address_space       = ["10.2.0.0/24"]
    location              = var.AzureLocationNE
    resource_group_name = azurerm_resource_group.CADDY.name

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}

# Create subnet
resource "azurerm_subnet" "CADDY-Subnet" {
    name                 = "CADDY-Subnet"
    resource_group_name  = azurerm_resource_group.CADDY.name
    virtual_network_name = azurerm_virtual_network.CADDY-Network.name
    address_prefixes       = ["10.2.0.0/24"]
}


# Create public IPs
resource "azurerm_public_ip" "CADDY-PUBLICIP" {
    name                        = "CADDY-PUBLICIP"
    location                    = var.AzureLocationNE
    resource_group_name         = azurerm_resource_group.CADDY.name
    allocation_method           = "Static"
    domain_name_label           = "caddymtls"

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create network interface
resource "azurerm_network_interface" "CADDY-NIC" {
    name                      = "CADDY-NIC"
    location                  = var.AzureLocationNE
    resource_group_name       = azurerm_resource_group.CADDY.name

    ip_configuration {
        name                          = "CADDY-NIC-Configuration"
        subnet_id                     = azurerm_subnet.CADDY-Subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.CADDY-PUBLICIP.id
    }

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "CADDY-NSG" {
    name                = "CADDY-NSG"
    location            = var.AzureLocationNE
    resource_group_name = azurerm_resource_group.CADDY.name
    
    security_rule {
        name                       = "ALLOW-ALL-FROM-OWN-IP"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.OwnRange
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "ALLOW-HTTP-FROM-WAN"
        priority                   = 1004
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "ALLOW-HTTPS-FROM-WAN"
        priority                   = 1005
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "CADDY-NSG-NIC-LINK" {
    network_interface_id      = azurerm_network_interface.CADDY-NIC.id
    network_security_group_id = azurerm_network_security_group.CADDY-NSG.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomIdCADDY" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.CADDY.name
    }
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "CADDY-StorageAccount" {
    name                        = "diag${random_id.randomIdCADDY.hex}"
    resource_group_name         = azurerm_resource_group.CADDY.name
    location                    = var.AzureLocationNE
    account_tier                = var.AzureStorageAccountTier
    account_replication_type    = var.AzureStorageAccountReplicationType

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}

resource "azurerm_virtual_machine" "CADDY-VM" {
    name                  = "CADDY"
    location              = var.AzureLocationNE
    resource_group_name   = azurerm_resource_group.CADDY.name
    network_interface_ids = [azurerm_network_interface.CADDY-NIC.id]
    vm_size               = var.VMSizeB1ms
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true

    storage_image_reference {
      publisher = var.OSPublisherUbuntu
      offer     = var.OSOfferUbuntu20
      sku       = var.OSSKUUbuntu20
      version   = var.OSVersion
    }

    storage_os_disk {
        name              = "CADDY-OSDISK"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    os_profile {
        computer_name         = "CADDY"
        admin_username        = var.CaddyUsername
        admin_password        = random_password.CaddyAdminPassword.result
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys{
            path        = "/home/${var.CaddyUsername}/.ssh/authorized_keys"
            key_data    = chomp(tls_private_key.CSCADDY_ssh.public_key_openssh)
        }
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = azurerm_storage_account.CADDY-StorageAccount.primary_blob_endpoint
    }

    provisioner "remote-exec"{
        inline = [
            "sudo -S apt-get update",
            "sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https",
            "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc",
            "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list",
            "sudo apt update",
            "sudo apt install caddy",
            "sudo cd /opt/; sudo mkdir certs"
            "sleep 10"
        ]
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.CADDY-PUBLICIP.ip_address
            user     = var.CaddyUsername
            private_key = tls_private_key.CSCADDY_ssh.private_key_pem
        }
    }
    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}