locals {
  primary_name = format("%s", random_string.primary.result)
  replication  = lower(var.environment) == "sandbox" ? "LRS" : contains(["dev", "qa", "nonprod"], lower(var.environment)) ? "GRS" : lower(var.environment) == "prod" && var.location == "canadacentral" ? "GZRS" : "RAGRS"
  default_tags = {
    environment    = var.environment
    location       = var.location
    resource_group = var.rg_name
  }
  tags = merge(local.default_tags, var.tags)
}