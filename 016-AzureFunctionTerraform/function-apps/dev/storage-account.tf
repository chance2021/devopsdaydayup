locals {
  storage-accounts = {
    storage1 = {
      purpose              = "dev-use"
      environment_instance = "dev1"
      storage_instance     = "1"
      storage_account_name = "chance20230719001"

    }
    storage2 = {
      purpose              = "dev-use"
      environment_instance = "dev2"
      storage_instance     = "2"
      storage_account_name = "chance20230719002"
    }
  }
}
