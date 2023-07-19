/**
resource "azurerm_data_factory" "main" {
  name                = "devopsdaydayup016"
  location            = azurerm_resource_group.devopsdaydayup.location
  resource_group_name = azurerm_resource_group.devopsdaydayup.name
  identity {
    type  = "SystemAssigned"
  }
  vsts_configuration {
    account_name = ""
    branch_name = ""
    project_name = ""
    repository_name = ""
    root_folder = ""
    tenant_id = ""
  }
}
**/