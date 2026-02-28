#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/infra/local/.env}"
RUN_APPLY="${1:-}"

echo "Provision Snowflake remote infrastructure with Terraform"
echo "Project root: $PROJECT_ROOT"
echo "Env file: $ENV_FILE"

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is not installed."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found at $ENV_FILE"
  echo "Run: make env"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${SNOWFLAKE_ACCOUNT:-}" || -z "${SNOWFLAKE_USER:-}" || -z "${SNOWFLAKE_PASSWORD:-}" ]]; then
  echo "Error: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER and SNOWFLAKE_PASSWORD are required in $ENV_FILE"
  exit 1
fi

if [[ "${SNOWFLAKE_ACCOUNT}" == "your_account" ]]; then
  echo "Error: SNOWFLAKE_ACCOUNT is still set to placeholder value 'your_account' in $ENV_FILE"
  exit 1
fi

SNOWFLAKE_ORG_NAME="${SNOWFLAKE_ORGANIZATION:-${SNOWFLAKE_ORGANIZATION_NAME:-}}"
SNOWFLAKE_ACCOUNT_IDENTIFIER="$SNOWFLAKE_ACCOUNT"

# Accept both styles:
# - SNOWFLAKE_ACCOUNT=vvyellg-cr56839
# - SNOWFLAKE_ORGANIZATION=vvyellg and SNOWFLAKE_ACCOUNT=cr56839
if [[ "$SNOWFLAKE_ACCOUNT_IDENTIFIER" != *"-"* ]]; then
  if [[ -n "$SNOWFLAKE_ORG_NAME" ]]; then
    SNOWFLAKE_ACCOUNT_IDENTIFIER="${SNOWFLAKE_ORG_NAME}-${SNOWFLAKE_ACCOUNT_IDENTIFIER}"
  else
    echo "Error: missing Snowflake organization."
    echo "Set SNOWFLAKE_ORGANIZATION (or SNOWFLAKE_ORGANIZATION_NAME) in $ENV_FILE or use SNOWFLAKE_ACCOUNT as <org>-<account>."
    exit 1
  fi
fi

echo "Using Snowflake account identifier: $SNOWFLAKE_ACCOUNT_IDENTIFIER"

ENVIRONMENT="${APP_ENV:-dev}"
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Error: APP_ENV must be dev or prod. Current: $ENVIRONMENT"
  exit 1
fi

if [[ "$ENVIRONMENT" == "dev" ]]; then
  PROVIDER_ROLE="${SNOWFLAKE_ROLE_DEV:-${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}"
else
  PROVIDER_ROLE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
fi

# Force Terraform provider to use password auth only (avoid conflicts with other auth env vars)
unset SNOWFLAKE_PRIVATE_KEY
unset SNOWFLAKE_PRIVATE_KEY_PATH
unset SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
unset SNOWFLAKE_AUTHENTICATOR
unset SNOWFLAKE_TOKEN
unset SNOWFLAKE_WAREHOUSE
unset SNOWSQL_WAREHOUSE

if [[ "$ENVIRONMENT" == "dev" ]]; then
  DATABASE_NAME="${SNOWFLAKE_DATABASE_DEV:-${SNOWFLAKE_DATABASE:-SENTINEL}_DEV}"
  WAREHOUSE_NAME="${SNOWFLAKE_WAREHOUSE_DEV:-${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL}_DEV}"
else
  DATABASE_NAME="${SNOWFLAKE_DATABASE:-SENTINEL}"
  WAREHOUSE_NAME="${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL}"
fi

pushd "$PROJECT_ROOT/infra/remote/snowflake" >/dev/null

if [[ -f terraform.tfvars ]]; then
  echo "Notice: terraform.tfvars found. Script values from $ENV_FILE will be used via -var-file."
fi

TMP_TFVARS="$(mktemp)"
trap 'rm -f "$TMP_TFVARS"' EXIT

cat > "$TMP_TFVARS" <<EOF
environment         = "$ENVIRONMENT"
snowflake_account   = "$SNOWFLAKE_ACCOUNT_IDENTIFIER"
snowflake_user      = "$SNOWFLAKE_USER"
snowflake_password  = "$SNOWFLAKE_PASSWORD"
snowflake_role      = "$PROVIDER_ROLE"
base_database_name  = "${SNOWFLAKE_DATABASE:-SENTINEL}"
base_warehouse_name = "${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL}"
base_role_name      = "${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
dev_role_name       = "${SNOWFLAKE_ROLE_DEV:-${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}"
EOF

TF_COMMON_ARGS=(-var-file="$TMP_TFVARS")

terraform init "${TF_COMMON_ARGS[@]}"

import_if_exists() {
  local resource="$1"
  local remote_id="$2"

  if terraform state show "${TF_COMMON_ARGS[@]}" "$resource" >/dev/null 2>&1; then
    echo "State already contains $resource"
    return 0
  fi

  echo "Attempting import: $resource <- $remote_id"
  if terraform import "${TF_COMMON_ARGS[@]}" "$resource" "$remote_id" >/dev/null 2>&1; then
    echo "Imported: $resource"
  else
    echo "Not found or not importable now: $resource (will be created by terraform apply)"
  fi
}

import_if_exists snowflake_warehouse.sentinel_wh "$WAREHOUSE_NAME"
import_if_exists snowflake_database.sentinel "$DATABASE_NAME"
import_if_exists snowflake_schema.bronze "${DATABASE_NAME}.BRONZE"
import_if_exists snowflake_schema.silver "${DATABASE_NAME}.SILVER"
import_if_exists snowflake_schema.gold "${DATABASE_NAME}.GOLD"

terraform plan "${TF_COMMON_ARGS[@]}"

if [[ "$RUN_APPLY" == "--apply" ]]; then
  terraform apply -auto-approve "${TF_COMMON_ARGS[@]}"
  echo "Snowflake remote infrastructure applied."
else
  echo "Plan complete. Re-run with --apply to execute changes."
fi

popd >/dev/null
