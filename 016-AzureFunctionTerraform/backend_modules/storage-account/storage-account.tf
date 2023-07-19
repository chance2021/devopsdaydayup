resource "azurerm_storage_account" "main" {
  name                     = "storage2023071988"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

}
