module "main" {
  source               = "../modules/dev"
  subscription_id      = var.subscription_id
  tenant_id            = var.tenant_id
  rg_name              = var.rg_name
  location             = var.location
  environment          = var.environment
  brand                = var.brand
  purpose              = "devops"
  environment_instance = "01"
  storage-accounts     = local.storage-accounts
  function-apps        = local.function-apps
}
