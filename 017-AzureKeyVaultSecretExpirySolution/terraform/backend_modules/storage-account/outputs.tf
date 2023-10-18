output "stroage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Name of storage account create"
}

output "storage_account_id" {
  value       = azurerm_storage_account.main.id
  description = "ID of storage account create"
}

output "storage_account_primary_access_key" {
  value       = azurerm_storage_account.main.primary_access_key
  description = "The primary accesss key for the storage account"
  sensitive   = true
}