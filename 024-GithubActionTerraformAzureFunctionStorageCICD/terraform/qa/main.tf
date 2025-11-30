module "function_storage" {
  source = "../modules/function_storage"
  environment = "qa"
  location    = "East US 2"
  # Add other environment-specific variables here
}
