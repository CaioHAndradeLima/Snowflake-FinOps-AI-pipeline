aws_region                      = "us-east-1"
project_name                    = "snowflake-sentinel"
environment                     = "dev"
bucket_name_override            = ""
snowflake_trusted_principal_arn = "arn:aws:iam::123456789001:user/abc1-b-self1234"
snowflake_external_id           = "snowflake-external-id-dev"
snowflake_allowed_prefixes      = ["snowflake/dev", "iceberg/dev"]
force_destroy_bucket            = true
