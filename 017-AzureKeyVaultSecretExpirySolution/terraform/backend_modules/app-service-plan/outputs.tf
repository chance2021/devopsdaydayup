
output "service_plan_id" {
  value       = azurerm_service_plan.main.id
  description = "The ID of the Service Plan"
}

output "service_plan_name" {
  value       = azurerm_service_plan.main.name
  description = "The Serivce Plan name"
}

output "service_plan_kind" {
  value       = azurerm_service_plan.main.kind
  description = "The Service Plan kind"
}

output "service_plan_reserved" {
  value       = azurerm_service_plan.main.reserved
  description = "Whether this is a reserved Service Plan Type. true if os_type is Linux, otherwise false"
}