variable "environment" {}
variable "brand" {}
variable "rg_name" {}
variable "location" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "purpose" {}
variable "environment_instance" {}

// Storage Account
variable "storage-accounts" { default = {} }

// App Service Plan
variable "app-service-plan" { default = {} }
// Logic App Standard
variable "logic-apps" { default = {} }