aws_region                      = "us-east-1"
project_name                    = "snowflake-sentinel"
environment                     = "prod"
bucket_name_override            = ""
snowflake_trusted_principal_arn = "arn:aws:iam::123456789001:user/abc1-b-self1234"
snowflake_external_id           = "snowflake-external-id-prod"
snowflake_allowed_prefixes      = ["snowflake/prod", "iceberg/prod"]
force_destroy_bucket            = false
