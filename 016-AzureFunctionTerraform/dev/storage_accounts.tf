locals {
  storage-accounts = {
    storage1 = {
      location                 = var.location
      environment              = var.environment
      rg_name                  = var.rg_name
      account_tier             = "Standard"
      account_replication_type = "LRS"
    }
  }
}
