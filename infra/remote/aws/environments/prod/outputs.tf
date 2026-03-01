output "lakehouse_bucket_name" {
  description = "S3 bucket used as lakehouse storage."
  value       = module.s3_lakehouse.bucket_name
}

output "lakehouse_bucket_arn" {
  description = "S3 bucket ARN."
  value       = module.s3_lakehouse.bucket_arn
}

output "lakehouse_kms_key_arn" {
  description = "KMS key ARN for bucket encryption."
  value       = module.kms.key_arn
}

output "snowflake_integration_role_arn" {
  description = "IAM role ARN to configure in Snowflake storage integration."
  value       = module.snowflake_integration_role.role_arn
}

output "snowflake_integration_role_name" {
  description = "IAM role name used by Snowflake integration."
  value       = module.snowflake_integration_role.role_name
}
