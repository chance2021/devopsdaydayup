locals {
  storage-accounts = {
    storage1 = {
      purpose              = "dev-use"
      environment_instance = "dev1"
      storage_instance     = "1"
      storage_account_name = "chance20230719001"
      account_tier         = "Standard"
      replication_override = "LRS"
    }
    storage2 = {
      purpose              = "dev-use"
      environment_instance = "dev2"
      storage_instance     = "2"
      storage_account_name = "chance20230719002"
      account_tier         = "Standard"
      replication_override = "LRS"
    }
  }
}
