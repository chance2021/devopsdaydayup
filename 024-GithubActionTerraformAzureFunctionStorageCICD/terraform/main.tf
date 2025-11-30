# main.tf for Azure Function and Storage
# Replace with your actual resource definitions

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "lab24-${var.environment}-rg"
  location = "East US"
}

resource "azurerm_storage_account" "storage" {
  name                     = "lab24${var.environment}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "function" {
  name                       = "lab24-${var.environment}-func"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  version                    = "~4"
  os_type                    = "linux"
}

resource "azurerm_app_service_plan" "plan" {
  name                = "lab24-${var.environment}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}
