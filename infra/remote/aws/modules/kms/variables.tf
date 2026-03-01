variable "alias_name" {
  type        = string
  description = "KMS alias name (without alias/ prefix)."
}

variable "description" {
  type        = string
  description = "KMS key description."
  default     = "KMS key for Snowflake Sentinel lakehouse data."
}

variable "deletion_window_in_days" {
  type        = number
  description = "Days before a scheduled key deletion is finalized."
  default     = 30
}

variable "enable_key_rotation" {
  type        = bool
  description = "Enable annual key rotation."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the KMS key."
  default     = {}
}
