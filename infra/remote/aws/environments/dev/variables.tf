variable "aws_region" {
  type        = string
  description = "AWS region for dev resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project slug used for naming."
  default     = "snowflake-sentinel"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "bucket_name_override" {
  type        = string
  description = "Optional explicit bucket name. Leave empty to auto-generate."
  default     = ""
}

variable "snowflake_trusted_principal_arn" {
  type        = string
  description = "Snowflake STORAGE_AWS_IAM_USER_ARN."

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(user|role)\\/.+", var.snowflake_trusted_principal_arn)) && !strcontains(var.snowflake_trusted_principal_arn, "123456789001")
    error_message = "snowflake_trusted_principal_arn must be a real IAM user/role ARN (not the placeholder example)."
  }
}

variable "snowflake_external_id" {
  type        = string
  description = "Snowflake STORAGE_AWS_EXTERNAL_ID."

  validation {
    condition     = trim(var.snowflake_external_id, " ") != "" && var.snowflake_external_id != "snowflake-external-id-dev"
    error_message = "snowflake_external_id must be set to the real value from Snowflake (not the example placeholder)."
  }
}

variable "snowflake_allowed_prefixes" {
  type        = list(string)
  description = "Allowed S3 prefixes for Snowflake integration role."
  default     = ["*"]
}

variable "force_destroy_bucket" {
  type        = bool
  description = "Allow destroy of non-empty bucket in dev."
  default     = true
}
