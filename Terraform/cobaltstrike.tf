#Deploy CS teamserver
# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "COBALT" {
    name     = "COBALT"
    location = var.AzureLocationNE

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create random password
resource "random_password" "CobaltAdminPassword" {
  length = 35
  special = true
  override_special = "_%@"
}

# Create virtual network
resource "azurerm_virtual_network" "Cobalt-Network" {
    name                = "Cobalt-VNet"
    address_space       = ["10.1.0.0/24"]
    location              = var.AzureLocationNE
    resource_group_name = azurerm_resource_group.COBALT.name

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}

# Create subnet
resource "azurerm_subnet" "Cobalt-Subnet" {
    name                 = "Cobalt-Subnet"
    resource_group_name  = azurerm_resource_group.COBALT.name
    virtual_network_name = azurerm_virtual_network.Cobalt-Network.name
    address_prefixes       = ["10.1.0.0/24"]
}


# Create public IPs
resource "azurerm_public_ip" "Cobalt-PUBLICIP" {
    name                        = "Cobalt-PUBLICIP"
    location                    = var.AzureLocationNE
    resource_group_name         = azurerm_resource_group.COBALT.name
    allocation_method           = "Static"
    domain_name_label           = "cobaltmtls"

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create network interface
resource "azurerm_network_interface" "Cobalt-NIC" {
    name                      = "Cobalt-NIC"
    location                  = var.AzureLocationNE
    resource_group_name       = azurerm_resource_group.COBALT.name

    ip_configuration {
        name                          = "Cobalt-NIC-Configuration"
        subnet_id                     = azurerm_subnet.Cobalt-Subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.Cobalt-PUBLICIP.id
    }

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "Cobalt-NSG" {
    name                = "Cobalt-NSG"
    location            = var.AzureLocationNE
    resource_group_name = azurerm_resource_group.COBALT.name
    
    security_rule {
        name                       = "ALLOW-ALL-FROM-OWN-RANGE"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.OwnRange
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}

resource "azurerm_network_security_rule" "CADDY-HTTPS"{
    name                       = "ALLOW-INCOMING-CADDY-HTTPS"
    priority                   = "2020"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_public_ip.CADDY-PUBLICIP.ip_address
    destination_address_prefix = "*"
    resource_group_name         = azurerm_resource_group.COBALT.name
    network_security_group_name = azurerm_network_security_group.Cobalt-NSG.name
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "Cobalt-NSG-NIC-LINK" {
    network_interface_id      = azurerm_network_interface.Cobalt-NIC.id
    network_security_group_id = azurerm_network_security_group.Cobalt-NSG.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomIdCS" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.COBALT.name
    }
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "Cobalt-StorageAccount" {
    name                        = "diag${random_id.randomIdCS.hex}"
    resource_group_name         = azurerm_resource_group.COBALT.name
    location                    = var.AzureLocationNE
    account_tier                = var.AzureStorageAccountTier
    account_replication_type    = var.AzureStorageAccountReplicationType

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}

# Create an SSH key
resource "tls_private_key" "CSCADDY_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "azurerm_virtual_machine" "Cobalt-VM" {
    name                  = "CobaltStrike"
    location              = var.AzureLocationNE
    resource_group_name   = azurerm_resource_group.COBALT.name
    network_interface_ids = [azurerm_network_interface.Cobalt-NIC.id]
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
        name              = "Cobalt-OSDISK"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    os_profile {
        computer_name         = "CobaltStrike"
        admin_username        = var.CobaltUsername
        admin_password        = random_password.CobaltAdminPassword.result
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys{
            path        = "/home/${var.CobaltUsername}/.ssh/authorized_keys"
            key_data    = chomp(tls_private_key.CSCADDY_ssh.public_key_openssh)
        }
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = azurerm_storage_account.Cobalt-StorageAccount.primary_blob_endpoint
    }

    provisioner "remote-exec"{
        inline = [
            "sudo apt-get update",
            "sudo apt-get -y install openjdk-11-jdk git net-tools certbot python3-certbot-apache",
            "sudo update-java-alternatives -s java-1.11.0-openjdk-amd64",
            "cd /opt/; sudo git clone https://github.com/FortyNorthSecurity/C2concealer",
            "sleep 10"
        ]
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.Cobalt-PUBLICIP.ip_address
            user     = var.CobaltUsername
            private_key = tls_private_key.CSCADDY_ssh.private_key_pem
        }
    }

    tags = {
        environment = "Terraform Cobalt Strike + Caddy"
    }
}