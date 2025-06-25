resource "azurerm_resource_group" "rg" {
  name     = "lab24-${var.environment}-${var.name}-rg"
  location = var.location
}

resource "time_sleep" "wait_for_rg" {
  depends_on = [azurerm_resource_group.rg]
  create_duration = "10s"
}

resource "azurerm_storage_account" "storage" {
  depends_on = [time_sleep.wait_for_rg]
  name                     = "lab24${var.environment}${var.name}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_service_plan" "plan" {
  depends_on = [time_sleep.wait_for_rg]
  name                = "lab24-${var.environment}-${var.name}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_function_app" "function" {
  name                       = "lab24-${var.environment}-${var.name}-func"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  version                    = "~4"
  os_type                    = "linux"
  https_only                 = true
}
