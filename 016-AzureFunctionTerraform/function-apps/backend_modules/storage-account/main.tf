resource "random_string" "primary" {
  length  = 3
  special = false
  upper   = false
}
resource "azurerm_storage_account" "main" {
  name                     = var.name_override == null ? lower(format("%sst", replace(local.primary_name, "/[[:^alnum:]]/", ""))) : lower(replace(var.name_override, "/[[:^alnum:]]/", ""))
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_override == null ? local.replication : var.replication_override
  tags                     = local.tags
}
