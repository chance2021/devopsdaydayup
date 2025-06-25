provider "azurerm" {
  features {}
}

module "function_storage" {
  for_each    = { for cfg in local.function_configs : cfg.name => cfg }
  source      = "../modules/function_storage"
  environment = "dev"
  location    = each.value.location
  name        = each.value.name
}
