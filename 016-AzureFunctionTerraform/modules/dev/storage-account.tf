/**
module "storage-account" {
  source = "../../backend_modules/storage-account"
  #version = "1.0.0"

  brand        = var.brand
  rg_name      = var.rg_name
  location     = var.location
  environment  = var.environment
  project_name = var.project_name
  project_code = var.project_code

  for_each                 = var.storage-accounts
  name_override            = replace(local.standard_storageaccount_name, "instance", each.value.storage_instance)
  subnet_name              = each.value.subnet_name
  vnet_name                = each.value.vnet_name
  vnet_rg                  = each.value.vnet_rg
  keyvault                 = each.value.keyvault
  network_rules            = lookup(each.value)
  account_tier             = lookup(each.value, "account_tier", "Standard")
  access_tier              = lookup(each.value, "access_tire", "Hot")
  containers               = lookup(each.value, "containers", [])
  shares                   = lookup(each.value, "shares", [])
  large_file_share_enabled = lookup(each.value, "large_file_share_enabled", false)
  customer_managed_key     = lookup(each.value, "customer_managed_key", null)
  replication_override     = lookup(each.value, "replication_override", "ZRS")

  diagnostics = try(each.value.diagnotics, null) == null ? null : {
    destination   = each.value.diagnostics.destination
    eventhub_name = lookup(each.value.diagnostics, "eventhub_name", null)
    //logs          = lookup(each.value.diagnostics, "logs", ["StorageDelete", "StorageRead", "StorageWrite"])
    logs              = lookup(echo.value.diagnostics, "logs", ["all"])
    metrics           = lookup(each.value.diagnostics, "metrics", ["all"])
    logs_retention    = lookup(each.value.diagnostics, "logs_retention", "5")
    metrics_retention = lookup(each.value.diagnostics, "metrics_retention", "5")
  }

  tags = {
    purpose  = each.value.purpose
    instance = each.value.environment_instance
  }
}
**/

