module "function-apps" {
  source = "../../backend_modules/function-apps"
  #version = "1.0.0"

  rg_name     = var.rg_name
  location    = var.location
  environment = var.environment

  for_each = var.function-apps

  function_app_name          = lookup(each.value, "function_app_name", null)
  app_service_plan_name      = lookup(each.value, "app_service_plan_name", null)
  app_service_plan_kind      = lookup(each.value, "app_service_plan_kind", null)
  app_service_plan_reserved  = lookup(each.value, "app_service_plan_reserved", null)
  app_service_plan_tier      = lookup(each.value.sku, "app_service_plan_tier", null)
  app_service_plan_size      = lookup(each.value.sku, "app_service_plan_size", null)
  app_service_plan_id        = lookup(each.value, "azurerm_app_service_plan", null)
  storage_account_name       = lookup(each.value, "storage_account_name", null)
  storage_account_access_key = lookup(each.value, "storage_account_access_key", null)
  function_app_os_type       = lookup(each.value, "function_app_os_type", null)
  function_app_version       = lookup(each.value, " function_app_version", null)

  depends_on = [module.storage-account]
}


