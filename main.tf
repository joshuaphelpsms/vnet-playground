provider "azurerm" {
  features {}
}

variable "region" {
  type    = string
  default = "westus3"
}

variable "rg" {
  type    = string
  default = "test2"
}

resource "random_string" "suffix" {
  keepers = {
    resource_group = var.rg
  }

  length  = 5
  upper   = false
  lower   = true
  numeric  = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg
  location = var.region
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "default" {
  name                = "default"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_network_security_group" "webapp" {
  name                = "webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "webapp" {
  name                 = "webapp"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "webapp"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "webapp" {
  subnet_id                 = azurerm_subnet.webapp.id
  network_security_group_id = azurerm_network_security_group.webapp.id
}

resource "azurerm_service_plan" "appSvcPlan" {
  name                = "appSvcPlan${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "webapp${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.appSvcPlan.location
  service_plan_id     = azurerm_service_plan.appSvcPlan.id

  virtual_network_subnet_id = azurerm_subnet.webapp.id

  // https://learn.microsoft.com/en-us/azure/app-service/configure-vnet-integration-routing
  // uses different (not the recommended) properties. Some are missing.
  site_config {
    vnet_route_all_enabled = true
  }
}
