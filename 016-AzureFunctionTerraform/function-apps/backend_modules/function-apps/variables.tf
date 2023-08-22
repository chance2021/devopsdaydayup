variable "app_service_plan_name" {}
variable "environment" {}
variable "location" {}
variable "rg_name" {}
variable "app_service_plan_kind" {}
variable "app_service_plan_reserved" {}
variable "app_service_plan_tier" {}
variable "app_service_plan_size" {}
variable "function_app_name" {}
variable "storage_account_name" {}
variable "storage_account_access_key" {}
variable "function_app_os_type" {}
variable "function_app_version" {}
variable "app_service_plan_id" {}
variable "linux_fx_versio" {
  default = "Python|3.11"
}
variable "ftps_state" {
  default = "Disabled"
}