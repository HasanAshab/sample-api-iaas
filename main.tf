variable "subscription" {
  description = "The subscription id of azure"
}

variable "location" {
  description = "Location of all resources"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.96.0"
    }
  }
  required_version = ">= 1.1.0"
}


provider "azurerm" {
  features {}

  subscription_id = var.subscription
}

resource "azurerm_resource_group" "rg" {
  name     = "rg"
  location = var.location
}

resource "azurerm_public_ip" "firewall" {
  name                = "firewall-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "management" {
  name                = "management-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/21"]
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.64/26"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_firewall" "default" {
  name                = "firewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  ip_configuration {
    name                 = "config"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "management"
    subnet_id            = azurerm_subnet.management.id
    public_ip_address_id = azurerm_public_ip.management.id
  }
}

resource "azurerm_firewall_nat_rule_collection" "default" {
  name = "firewall-web-rule-collection"
  azure_firewall_name = azurerm_firewall.default.name
  resource_group_name = azurerm_resource_group.rg.name
  priority = 100
  action = "Dnat"

  rule {
    name = "web-rule"
    source_addresses = [ "*" ]
    destination_ports = [ "4000" ]
    destination_addresses = [ azurerm_public_ip.firewall.ip_address ]
    translated_address = azurerm_linux_virtual_machine.web.private_ip_address
    translated_port = "80"
    protocols = [ "TCP" ]
  }
}

# resource "azurerm_firewall_policy" "example" {
#   name                = "firewall-policy"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
# }

resource "azurerm_network_interface" "nic" {
  name                = "nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                = "web"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/hasan_rsa.pub")
  }
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}


output "firewall_url" {
  description = "Public URL to access the web server through Azure Firewall"
  value       = format("http://%s:%s", azurerm_public_ip.firewall.ip_address, "4000")
}