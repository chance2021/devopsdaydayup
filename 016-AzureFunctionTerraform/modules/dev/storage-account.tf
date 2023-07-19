module "storage-account" {
  source = "../../backend_modules/storage-account"
  #version = "1.0.0"

  rg_name         = var.rg_name
  location        = var.location
  environment     = var.environment
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  for_each = var.storage-accounts
  ##name_override            = replace(local.standard_storageaccount_name, "instance", each.value.storage_instance)
  storageaccount_name      = lookup(each.value, "storageaccount_name", null)
  account_tier             = lookup(each.value, "account_tier", "Standard")
  account_replication_type = lookup(each.value, "account_replication_type", "LRS")

  depends_on = [module.resource-group]
}

