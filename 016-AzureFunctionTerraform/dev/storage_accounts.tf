/**
locals {
  storage_accounts = {
    storage1 = {
      purpose                  = "sale"
      environment_instance     = "dev1"
      storage_instance         = "1"
      subnet_name              = var.data_subnet_name
      vnet_name                = var.vnet_name
      vnet_rg                  = var.vnet_rg
      large_file_share_enabled = "false"
      replication_override     = "LRS"

      diagnostics = {
        destination = data.azurerm_log_analytics_workspace.la.id
      }

      keyvault = {
        enabled     = true
        resource_id = module.main.vault_id["keyvault1"]
      }

      shares = []
      containers = [
        {
          name                  = "sale-west"
          container_access_type = "private"
        }
      ]
    }
  }
}
**/