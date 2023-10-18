module "main" {
  source               = "../modules/dev"
  subscription_id      = var.subscription_id
  tenant_id            = var.tenant_id
  rg_name              = var.rg_name
  location             = var.location
  environment          = var.environment
  brand                = var.brand
  purpose              = var.purpose
  environment_instance = var.environment_instance

  storage-accounts = local.storage-accounts
  app-service-plan = local.app-service-plan
  logic-apps       = local.logic-apps

}
