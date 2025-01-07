module "resource-group" {
  source      = "../../backend_modules/resource-group"
  rg_name     = var.rg_name
  location    = var.location
}