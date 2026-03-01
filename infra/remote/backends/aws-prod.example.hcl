bucket         = "replace-with-terraform-state-bucket-name"
key            = "aws/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "snowflake-sentinel-terraform-locks"
encrypt        = true
