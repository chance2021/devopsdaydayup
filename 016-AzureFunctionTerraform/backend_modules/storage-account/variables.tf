variable "environment" {}
variable "rg_name" {}
variable "location" {}
variable "account_tier" {}
//variable "account_replication_type" {}
variable "replication_override" {}
variable "storage_account_name" {}
variable "tags" {}
variable "large_file_share_enabled" {}
variable "name_override" {
  description = "Setting this will override the default naming convention but will still append 'st' to the end of the name"
  type        = string
  default     = null
}