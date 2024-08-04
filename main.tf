terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.112.0"
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
  keyvault      = "xxx4"
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
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "subA" {
  name                 = local.subnet
  resource_group_name  = local.resourcegroup
  virtual_network_name = local.vnet
  address_prefixes     = ["10.0.0.0/24"]
  depends_on           = [azurerm_virtual_network.vnetA]
}

resource "azurerm_network_interface" "nicA" {
  name                = "NICA"
  location            = local.location
  resource_group_name = local.resourcegroup
  depends_on          = [azurerm_subnet.subA]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subA.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

#kv i sekret

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv2" {
  name                        = local.keyvault
  location                    = local.location
  resource_group_name         = local.resourcegroup
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  depends_on                  = [azurerm_resource_group.rg]
}

resource "azurerm_user_assigned_identity" "MID" {
  name                = "MID"
  resource_group_name = local.resourcegroup
  location            = local.location
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_key_vault_access_policy" "IAMKV" {
  key_vault_id = azurerm_key_vault.kv2.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.MID.principal_id
  depends_on   = [azurerm_user_assigned_identity.MID]

  secret_permissions = [
    "Get", "List", "Delete", "Set"
  ]
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmPassword"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.kv2.id
  depends_on   = [azurerm_key_vault.kv2]
}

resource "azurerm_key_vault_secret" "vmlogin" {
  name         = "vmlogin"
  value        = "julka123"
  key_vault_id = azurerm_key_vault.kv2.id
  depends_on   = [azurerm_key_vault.kv2]
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = local.vm
  resource_group_name = local.resourcegroup
  location            = local.location
  size                = "Standard_F2"
  admin_username      = azurerm_key_vault_secret.vmlogin.value
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  depends_on = [
    azurerm_network_interface.nicA,
    azurerm_key_vault_secret.vmpassword,
    azurerm_key_vault_secret.vmlogin
  ]
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