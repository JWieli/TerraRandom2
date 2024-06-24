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

locals {
  resourcegroup = "Test1"
  location      = "West Europe"
  vnet          = "vnetA"
  subnet        = "subnetA"
  vm            = "vm1"
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

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}