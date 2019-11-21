terraform {
required_version = ">= 0.11"
backend "azurerm" {
storage_account_name = "__terraformstorageaccount__"
container_name       = "terraform"
key                  = "terraform.tfstate"
access_key           = "__storagekey__"
}
}

resource "azurerm_resource_group" "rg" {
name     = "__resource_group__"
location = "__location__"
}

resource "azurerm_virtual_network" "vnet" {
name                = "${var.virtual_network_name}"
location            = "__location__"
address_space       = ["${var.address_space}"]
resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnetfrontend" {
name                 = "${var.subnetname_prefixfrontend}"
virtual_network_name = "${azurerm_virtual_network.vnet.name}"
resource_group_name  = "${azurerm_resource_group.rg.name}"
address_prefix       = "${var.subnet_prefixfrontend}"
}

resource "azurerm_subnet" "subnetbackend" {
name                 = "${var.subnetname_prefixbackend}"
virtual_network_name = "${azurerm_virtual_network.vnet.name}"
resource_group_name  = "${azurerm_resource_group.rg.name}"
address_prefix       = "${var.subnet_prefixbackend}"
}

resource "azurerm_public_ip" "VM1Publicip" {
    name                         = "${var.publicIPname}"
    location                     = "__location__"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    allocation_method            = "Dynamic"
}

resource "azurerm_network_security_group" "vm1NSG" {
    name                = "vm1NSG"
    location            = "__location__"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}
resource "azurerm_network_interface" "VM1NIC" {
    name                        = "VM1NIC"
    location                    = "__location__"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    network_security_group_id   = "${azurerm_network_security_group.vm1NSG.id}"

    ip_configuration {
        name                          = "VM1NICConfig"
        subnet_id                     = "${azurerm_subnet.subnetfrontend.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.VM1Publicip.id}"
    }
}

resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.rg.name}"
    }  
    byte_length = 8
}
resource "azurerm_storage_account" "vm1diagstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    location                    = "__location__"
    account_replication_type    = "LRS"
    account_tier                = "Standard"
}

resource "azurerm_virtual_machine" "VM1" {
    name                  = "VM1"
    location              = "__location__"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    network_interface_ids = ["${azurerm_network_interface.VM1NIC.id}"]
    vm_size               = "Standard_DS1"

    storage_os_disk {
        name              = "VM1OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "VM1"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa <insert-your SSH key here>"
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = "${azurerm_storage_account.vm1diagstorageaccount.primary_blob_endpoint}"
    }

}