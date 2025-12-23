module "function_storage" {
  source = "../modules/function_storage"
  environment = "staging"
  location    = "Central US"
  # Add other environment-specific variables here
}
