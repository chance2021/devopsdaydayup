locals {
  default_tags = {
    environment    = var.environment
    location       = var.location
    resource_group = var.rg_name
  }
  tags = merge(local.default_tags, var.tags)
}