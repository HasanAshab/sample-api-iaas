terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "portfolio-prod-centralindia-sampleapi-RG"
  location = "Central India"
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = "portfolio-prod-centralindia-sampleapi-VNET"
  address_prefixes     = ["237.84.2.178/24"]
}
resource "azurerm_network_interface" "nic" {
  name                = "portfolio-prod-centralindia-sampleapi-NIC"
  location            = "Central India"
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_virtual_machine" "vm" {
  name = "portfolio-prod-centralindia-sampleapi"
  location = "Central India"
  vm_size = "Standard_D2s_v3"
  resource_group_name = azurerm_resource_group.rg.name
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  network_interface_ids = [azurerm_network_interface.nic.id]
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_profile {
    computer_name  = "myvm"
    admin_username = "azureuser"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}
