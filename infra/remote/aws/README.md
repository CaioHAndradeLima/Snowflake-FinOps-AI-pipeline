# AWS Remote Terraform

This directory contains AWS IaC split into:

- `state-backend/`: S3 + DynamoDB resources for remote Terraform state.
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

1. Provision remote Terraform state backend (one-time):

```bash
cp infra/remote/aws/state-backend/terraform.example.tfvars infra/remote/aws/state-backend/terraform.tfvars
make aws-state-backend-plan
make aws-state-backend-apply
```

Fully automated one-command version:

```bash
make bootstrap-remote-state-auto
```

2. Create backend config files and migrate state:

```bash
cp infra/remote/backends/aws-dev.example.hcl infra/remote/backends/aws-dev.hcl
cp infra/remote/backends/aws-prod.example.hcl infra/remote/backends/aws-prod.hcl
cp infra/remote/backends/snowflake-dev.example.hcl infra/remote/backends/snowflake-dev.hcl

make init-state-aws-dev
make init-state-aws-prod
make init-state-snowflake-dev
```

3. Bootstrap roles (one-time):

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

4. Prepare tfvars for each environment:

```bash
cp infra/remote/aws/environments/dev/terraform.example.tfvars infra/remote/aws/environments/dev/terraform.tfvars
cp infra/remote/aws/environments/prod/terraform.example.tfvars infra/remote/aws/environments/prod/terraform.tfvars
```

5. Apply environments:

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

Bootstrap can enable GitHub OIDC trust directly:

```bash
ENABLE_GITHUB_OIDC=true \
GITHUB_REPOSITORY=<owner/repo> \
GITHUB_REF_PATTERNS=refs/heads/main,refs/heads/develop \
make aws-bootstrap-apply
```

Repository secrets expected by `.github/workflows/terraform-aws-dev.yml`:

- `AWS_REGION`
- `AWS_ROLE_ARN_DEV`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `SNOWFLAKE_TRUSTED_PRINCIPAL_ARN_DEV`
- `SNOWFLAKE_EXTERNAL_ID_DEV`
