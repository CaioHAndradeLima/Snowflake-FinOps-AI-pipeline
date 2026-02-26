variable "environment" {
  type        = string
  description = "Deployment environment: dev or prod."
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either dev or prod."
  }
}

variable "snowflake_account_name" {
  type        = string
  description = "Snowflake account name."
}

variable "snowflake_organization_name" {
  type        = string
  description = "Snowflake organization name."
}

variable "snowflake_user" {
  type        = string
  description = "Terraform user."
}

variable "snowflake_password" {
  type        = string
  sensitive   = true
  description = "Terraform user password."
}

variable "snowflake_role" {
  type        = string
  description = "Role used by Terraform provider."
  default     = "ACCOUNTADMIN"
}

variable "base_database_name" {
  type        = string
  description = "Base database name for prod. Dev gets _DEV suffix."
  default     = "SENTINEL"
}

variable "base_warehouse_name" {
  type        = string
  description = "Base warehouse name for prod. Dev gets _DEV suffix."
  default     = "WH_SENTINEL"
}

variable "base_role_name" {
  type        = string
  description = "Role name for prod grants."
  default     = "ACCOUNTADMIN"
}

variable "dev_role_name" {
  type        = string
  description = "Role name for dev grants."
  default     = "ACCOUNTADMIN"
}

variable "warehouse_size" {
  type        = string
  description = "Snowflake warehouse size."
  default     = "XSMALL"
}
