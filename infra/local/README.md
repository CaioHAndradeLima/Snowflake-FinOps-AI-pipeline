# Local Infra (Docker)

This stack provides local developer containers for:
- `app`: Python runtime for Snowpark and app scripts.
- `dbt`: dbt-snowflake runtime.
- `terraform`: Terraform CLI runtime for remote Snowflake IaC.

## Prerequisites

- Docker Desktop running
- `infra/local/.env` created (`make env`)

## Commands

```bash
make local-up
make local-ps
make local-logs
make local-down
```

Shell access:

```bash
make local-shell-app
make local-shell-dbt
make local-shell-tf
```

## dbt Profile

`DBT_PROFILES_DIR` is configured to:

`/workspace/infra/local/dbt`

The profile file is:

`infra/local/dbt/profiles.yml`
