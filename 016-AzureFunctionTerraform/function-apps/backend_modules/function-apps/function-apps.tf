resource "azurerm_app_service_plan" "main" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.rg_name
  kind                = var.app_service_plan_kind
  reserved            = var.app_service_plan_reserved

  sku {
    tier = var.app_service_plan_tier
    size = var.app_service_plan_size
  }
}

# resource "azurerm_function_app" "main" {
#   name                       = var.function_app_name
#   location                   = var.location
#   resource_group_name        = var.rg_name
#   app_service_plan_id        = azurerm_app_service_plan.main.id
#   storage_account_name       = var.storage_account_name
#   storage_account_access_key = var.storage_account_access_key
#   os_type                    = var.function_app_os_type
#   version                    = var.function_app_version
# }

resource "azurerm_linux_function_app" "main" {
  name                = var.function_app_name
  resource_group_name = var.rg_name
  location            = var.location

  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_access_key
  service_plan_id            = azurerm_app_service_plan.main.id
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
  }

  site_config {
    # linux_fx_version = "Python|3.11"
    # ftps_state       = "Disabled"
  }
}