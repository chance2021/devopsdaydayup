locals {
  storage-accounts = {
    storage1 = {
      standard_storage_account_name = "chance20230719001"
      account_tier                  = "Standard"
      account_replication_type      = "LRS"
      purpose                       = "devopschance"
      environment_instance          = "dev01"
      storage_instance              = "01"
    }
    storage2 = {
      standard_storage_account_name = "chance20230719002"
      account_tier                  = "Standard"
      account_replication_type      = "LRS"
      purpose                       = "devopschance"
      environment_instance          = "dev02"
      storage_instance              = "02"
    }
  }
}
