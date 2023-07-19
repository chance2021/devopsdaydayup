module "main" {
  source          = "../modules/dev"
  rg_name         = var.rg_name
  location        = var.location
  environment     = var.environment
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
