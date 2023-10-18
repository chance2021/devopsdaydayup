locals {
  app-service-plan = {
    app_service_plan_01 = {
      rg_name               = var.rg_name
      location              = var.location
      app_service_plan_name = "devops-app-service-plan"
      os_type               = "Windows"
      sku_name              = "WS1"
    }
  }
}