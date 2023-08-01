locals {
  function-apps = {
    function_devops_01 = {
      app_service_plan_name      = "devops-app-service-plan"
      app_service_plan_kind      = "Linux"
      app_service_plan_reserved  = "true"
      function_app_name          = "devops-function-app-20230719"
      storage_account_access_key = "test"
      function_app_os_type       = "linux"
      function_app_version       = "~3"
      # TODO: Need to change it to dynamical value
      storage_account_name = "chance20230719001"
      sku = {
        app_service_plan_tier = "Dynamic"
        app_service_plan_size = "Y1"
      }
    }
  }
}
