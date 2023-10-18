locals {
  logic-apps = {
    function_devops_01 = {
      app_service_plan = {
        id = module.main.app_service_plan_id["app_service_plan_01"]
      }
      logicapp_name = "devops-function-app-20230719"
      storage_account = {
        name       = module.main.strorage_account_name["storage1"]
        access_key = module.main.storage_account_access_key["storage1"]
      }
    }
  }
}
