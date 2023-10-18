terraform {
  required_version = ">= 1.0.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<=3.40.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {}
}