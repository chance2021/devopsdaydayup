variable "environment" {
  description = "Deployment environment (dev, qa, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "name" {
  description = "Name for the function app and related resources"
  type        = string
}
