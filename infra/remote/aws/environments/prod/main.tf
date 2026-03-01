data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : lower(
    "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-lakehouse"
  )

  kms_alias = "${var.project_name}-${var.environment}-lakehouse"
  role_name = "SnowflakeStorageIntegrationRoleProd"
}

module "kms" {
  source = "../../modules/kms"

  alias_name  = local.kms_alias
  description = "KMS key for ${var.project_name} ${var.environment} lakehouse bucket."
  tags        = local.common_tags
}

module "s3_lakehouse" {
  source = "../../modules/s3_lakehouse"

  bucket_name           = local.bucket_name
  kms_key_arn           = module.kms.key_arn
  force_destroy         = var.force_destroy_bucket
  transition_to_ia_days = 30
  expire_after_days     = 365
  tags                  = local.common_tags
}

module "snowflake_integration_role" {
  source = "../../modules/snowflake_integration_role"

  role_name             = local.role_name
  trusted_principal_arn = var.snowflake_trusted_principal_arn
  external_id           = var.snowflake_external_id
  bucket_name           = module.s3_lakehouse.bucket_name
  bucket_arn            = module.s3_lakehouse.bucket_arn
  kms_key_arn           = module.kms.key_arn
  allowed_prefixes      = var.snowflake_allowed_prefixes
  tags                  = local.common_tags
}
