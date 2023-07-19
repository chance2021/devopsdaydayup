resource "random_string" "primary" {
  length  = 3
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                              = var.name_override == null ? lower(format("%sst", replace(local.primary_name, "/[[:^alnum:]]/", ""))) : lower(replace(var.name_override, "/[[:^alnum:]]/", ""))
  name                     = "storageaccountname"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}
