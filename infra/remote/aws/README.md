# AWS Remote Terraform

This directory contains AWS IaC split into:

- `bootstrap/`: creates Terraform execution roles (`Dev` and `Prod`).
- `modules/`: shared reusable Terraform modules.
- `environments/dev` and `environments/prod`: environment-specific stacks.

## Modules

- `kms`: creates KMS key + alias for encryption at rest.
- `s3_lakehouse`: creates secure S3 bucket for lakehouse/metadata storage.
- `snowflake_integration_role`: creates IAM role trusted by Snowflake with scoped S3/KMS access.

## Why these resources

- S3 gives durable and low-cost storage for historical metadata and Iceberg-compatible objects.
- KMS provides customer-managed encryption and key access control.
- Snowflake integration role enforces least-privilege access from Snowflake to only allowed bucket/prefixes.

## Execution Order

1. Bootstrap roles (one-time):

```bash
make aws-bootstrap-plan
make aws-bootstrap-apply
```

One-command first-time dev setup (recommended):

```bash
make aws-first-time-dev
```

This command:
- checks AWS CLI identity and derives a temporary trusted principal.
- updates `dev/terraform.tfvars` automatically.
- applies bootstrap + dev AWS resources.
- if `snowsql` is available and `infra/local/.env` is configured, creates/reads Snowflake storage integration metadata.
- rewrites trust vars with real Snowflake values and reapplies dev.

2. Prepare tfvars for each environment:

```bash
cp infra/remote/aws/environments/dev/terraform.example.tfvars infra/remote/aws/environments/dev/terraform.tfvars
cp infra/remote/aws/environments/prod/terraform.example.tfvars infra/remote/aws/environments/prod/terraform.tfvars
```

3. Apply environments:

```bash
make aws-dev-plan
make aws-dev-apply
make aws-prod-plan
make aws-prod-apply
```

## Required Snowflake Values for IAM Trust

`snowflake_trusted_principal_arn` and `snowflake_external_id` must come from Snowflake storage integration metadata.
Do not use the placeholders in `terraform.example.tfvars`.

Example flow in Snowflake:

```sql
CREATE OR REPLACE STORAGE INTEGRATION SENTINEL_S3_INT_DEV
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<your-account-id>:role/SnowflakeStorageIntegrationRoleDev'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<your-dev-bucket>/');

DESC INTEGRATION SENTINEL_S3_INT_DEV;
```

From `DESC INTEGRATION`, copy:

- `STORAGE_AWS_IAM_USER_ARN` -> `snowflake_trusted_principal_arn`
- `STORAGE_AWS_EXTERNAL_ID` -> `snowflake_external_id`

Then update `infra/remote/aws/environments/<env>/terraform.tfvars` and apply again.

## CI/CD (GitHub Actions) direction

For CI, use AWS OIDC role assumption and avoid static AWS keys:

- GitHub Actions obtains short-lived credentials via OIDC.
- Workflow assumes `TerraformExecutionRoleDev` for dev workflows.
- Workflow assumes `TerraformExecutionRoleProd` for prod workflows.
- Keep prod apply protected by manual approval branch/environment rules.
