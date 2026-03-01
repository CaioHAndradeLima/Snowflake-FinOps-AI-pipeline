variable "role_name" {
  type        = string
  description = "IAM role name used by Snowflake storage integration."
}

variable "trusted_principal_arn" {
  type        = string
  description = "AWS principal ARN provided by Snowflake STORAGE_AWS_IAM_USER_ARN."
}

variable "external_id" {
  type        = string
  description = "External ID provided by Snowflake STORAGE_AWS_EXTERNAL_ID."
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name allowed for Snowflake access."
}

variable "bucket_arn" {
  type        = string
  description = "S3 bucket ARN allowed for Snowflake access."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN to allow decrypt/encrypt operations."
}

variable "allowed_prefixes" {
  type        = list(string)
  description = "List of allowed S3 key prefixes inside bucket."
  default     = ["*"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to role and policy."
  default     = {}
}
