data "azurerm_service_plan" "existing" {
  count               = try(length(var.app_service_plan.name) > 0, false) ? 1 : 0
  name                = var.app_service_plan.name
  resource_group_name = var.resource_group_name
}