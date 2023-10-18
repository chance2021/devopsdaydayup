// App Service Plan
output "app_service_plan_name" {
  value = { for k, v in module.app_service_plan : k => v.service_plan_name }
}


output "app_service_plan_id" {
  value = { for k, v in module.app_service_plan : k => v.service_plan_id }
}

// Storage Account
output "strorage_account_name" {
  value = { for k, v in module.storage-account : k => v.stroage_account_name }
}

output "storage_account_id" {
  value = { for k, v in module.storage-account : k => v.storage_account_id }
}

output "storage_account_access_key" {
  value = { for k, v in module.storage-account : k => v.storage_account_primary_access_key }
}