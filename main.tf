terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}
#var
locals {
  resourcegroup = "Test1"
  location      = "West Europe"
  vnet          = "vnetA"
  subnet        = "subnetA"
  vm            = "vm1"
  keyvault      = "kv1"
}

resource "azurerm_resource_group" "rg" {
  location = local.location
  name     = local.resourcegroup
  tags = {
    environment = "development"
  }
}

resource "azurerm_virtual_network" "vnetA" {
  name                = local.vnet
  location            = local.location
  resource_group_name = local.resourcegroup
  address_space       = ["10.0.0.0/23"]
}

resource "azurerm_subnet" "subA" {
  name                 = local.subnet
  resource_group_name  = local.resourcegroup
  virtual_network_name = local.vnet
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "nicA" {
  name                = "NICA"
  location            = local.location
  resource_group_name = local.resourcegroup

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subA.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = local.vm
  resource_group_name = local.resourcegroup
  location            = local.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "julka123123!"
  network_interface_ids = [
    azurerm_network_interface.nicA.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

#kv i sekret

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = local.keyvault
  location                    = local.location
  resource_group_name         = local.resourcegroup
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
}

resource "azurerm_user_assigned_identity" "MID" {
  name                = "MID"
  resource_group_name = local.resourcegroup
  location            = local.location
}

  resource "azurerm_key_vault_access_policy" "IAMKV" {
    key_vault_id = azurerm_key_vault.kv.id
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.MID.principal_id

    secret_permissions = [
      "Get", "List", "Delete", "Set"
    ]
  }

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# resource "azurerm_key_vault_secret" "vm_password" {
#   name         = "vmPassword"
#   value        = random_password.password.result
#   key_vault_id = azurerm_key_vault.example.id
# }