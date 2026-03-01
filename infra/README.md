# Infra Architecture Guide

## Why Terraform with Shared Code

Yes, Terraform should use shared code for multiple environments.

The standard pattern is:

- `modules/`: reusable building blocks (write once).
- `environments/dev` and `environments/prod`: thin wrappers that call modules with different inputs.

This avoids duplication and keeps `dev` and `prod` consistent while still allowing different limits, names, and policies.

## Current Structure

```plaintext
infra/
├── local/
│   ├── docker-compose.yml
│   ├── docker/
│   │   ├── app/
│   │   └── dbt/
│   └── scripts/
│       ├── generate-env.sh
│       ├── provision_snowflake_remote.sh
│       └── provision_aws_bootstrap.sh
└── remote/
    ├── snowflake/
    └── aws/
        └── bootstrap/
```

## Remote AWS Structure

```plaintext
infra/remote/aws/
├── bootstrap/
├── modules/
│   ├── s3_lakehouse/
│   ├── kms/
│   └── snowflake_integration_role/
└── environments/
    ├── dev/
    └── prod/
```

Bootstrap and usage details: `infra/remote/aws/README.md`

## Why Each AWS Component Is Needed

### 1) S3 Lakehouse (`s3_lakehouse`)

Purpose:

- Store Snowflake metadata exports and Iceberg-compatible objects.
- Provide durable, low-cost storage outside Snowflake native tables for long retention.

Why required:

- Supports historical analysis and cost/performance trend tracking.
- Reduces long-term storage cost for audit/observability data.

### 2) KMS (`kms`)

Purpose:

- Encrypt S3 data using customer-managed keys.

Why required:

- Security and compliance baseline (data at rest with key control).
- Allows controlled decrypt permissions and auditability.

### 3) Snowflake Integration IAM Role (`snowflake_integration_role`)

Purpose:

- Dedicated IAM role that Snowflake assumes to access S3.

Why required:

- Least-privilege access from Snowflake to only the intended bucket/prefix.
- Clear trust boundary and easier audit trail.

### 4) Bootstrap Execution Roles (`aws/bootstrap`)

Purpose:

- `TerraformExecutionRoleDev` and `TerraformExecutionRoleProd` for running Terraform safely by environment.

Why required:

- Separation of duties and blast-radius control.
- `dev` changes cannot accidentally impact `prod`.

## Environment Strategy

- Same modules for `dev` and `prod`.
- Different inputs per environment:
  - names/tags
  - retention rules
  - role scope
  - optional guardrails (stricter on `prod`)
- Separate Terraform state per environment.
