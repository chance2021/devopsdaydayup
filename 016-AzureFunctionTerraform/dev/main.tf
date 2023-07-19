module "main" {
  source          = "../modules/dev"
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  rg_name         = var.rg_name
  location        = var.location
  environment     = var.environment

  storage-accounts = local.storage-accounts
}
