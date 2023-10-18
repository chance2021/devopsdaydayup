resource "azurerm_logic_app_standard" "main" {
  name                       = var.logicapp_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  app_service_plan_id        = var.app_service_plan.id
  storage_account_name       = var.storage_account.name
  storage_account_access_key = var.storage_account.access_key
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
  }
}