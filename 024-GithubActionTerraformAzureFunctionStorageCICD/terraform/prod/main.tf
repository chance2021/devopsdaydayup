module "function_storage" {
  source = "../modules/function_storage"
  environment = "prod"
  location    = "West US"
  # Add other environment-specific variables here
}
