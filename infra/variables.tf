variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "loupgarou-rg"
}

variable "acr_name" {
  description = "Azure Container Registry name — must be globally unique, alphanumeric only"
  type        = string
}

variable "aks_name" {
  description = "AKS cluster name"
  type        = string
  default     = "loupgarou-aks"
}

variable "sql_server_name" {
  description = "Azure SQL Server name — must be globally unique"
  type        = string
}

variable "sql_admin_login" {
  description = "SQL Server admin username"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "SQL Database name"
  type        = string
  default     = "LoupGarou"
}