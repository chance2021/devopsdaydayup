module "logic_app_standard" {
  source              = "../../backend_modules/logic-app-standard"
  resource_group_name = var.rg_name
  location            = var.location

  for_each         = var.logic-apps
  logicapp_name    = each.value.logicapp_name
  app_service_plan = each.value.app_service_plan
  storage_account  = each.value.storage_account
}