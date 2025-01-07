locals {
  storage-accounts = {
    storage1 = {
      account_tier             = "Standard"
      account_replication_type = "LRS"
      purpose                  = "devopschance"
      environment_instance     = "dev01"
      storage_instance         = "01"
    }
    storage2 = {
      account_tier             = "Standard"
      account_replication_type = "LRS"
      purpose                  = "devopschance"
      environment_instance     = "dev02"
      storage_instance         = "02"
    }
  }
}
