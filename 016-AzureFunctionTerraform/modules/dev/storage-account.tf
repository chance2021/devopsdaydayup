module "storage-account" {
  source = "../../backend_modules/storage-account"
  #version = "1.0.0"

  rg_name     = var.rg_name
  location    = var.location
  environment = var.environment

  for_each                  = var.storage-accounts
  name_override             = replace(local.standard_storage_account_name, "instance", each.value.storage_instance)
  storage_account_name      = lookup(each.value, "storage_account_name", null)
  account_tier              = lookup(each.value, "account_tier", "Standard")
  replication_override      = lookup(each.value, "replication_override", "LRS")
  shared_access_key_enabled = false

  tags = {
    purpose  = each.value.purpose
    instance = each.value.environment_instance
  }
  depends_on = [module.resource-group]
}

