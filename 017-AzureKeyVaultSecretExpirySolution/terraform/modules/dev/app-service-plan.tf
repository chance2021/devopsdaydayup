module "app_service_plan" {
  source = "../../backend_modules/app-service-plan"

  for_each              = var.app-service-plan
  app_service_plan_name = each.value.app_service_plan_name
  rg_name               = each.value.rg_name
  location              = each.value.location
  os_type               = each.value.os_type
  sku_name              = each.value.sku_name
  depends_on            = [module.resource-group]
}