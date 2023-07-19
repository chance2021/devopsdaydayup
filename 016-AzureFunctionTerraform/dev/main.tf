module "main" {
  source   = "../modules/dev"
  rg_name  = var.rg_name
  location = var.location
  # environment     = var.environment
  environment     = "dev"
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  storage-accounts = local.storage-accounts
}
