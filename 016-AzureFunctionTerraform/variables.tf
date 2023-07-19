variable "environment" {}
variable "rg_name" {}
variable "location" {}
variable "subscription_id" {}
variable "tenant_id" {}

variable "storage-accounts" { default = {} }
variable "function-apps" { default = {} }