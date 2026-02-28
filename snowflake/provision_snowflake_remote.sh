#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "Provision Snowflake remote infrastructure with Terraform"

load_env
require_cmd terraform

export TF_VAR_snowflake_account_name="$SNOWFLAKE_ACCOUNT"
export TF_VAR_snowflake_organization_name="${SNOWFLAKE_ORGANIZATION_NAME}"
export TF_VAR_snowflake_user="$SNOWFLAKE_USER"
export TF_VAR_snowflake_password="$SNOWFLAKE_PASSWORD"
export TF_VAR_snowflake_role="$SNOWFLAKE_ROLE"

# Force Terraform provider to use password auth only (avoid conflicts with key-pair env vars)
unset SNOWFLAKE_PRIVATE_KEY
unset SNOWFLAKE_PRIVATE_KEY_PATH
unset SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
unset SNOWFLAKE_AUTHENTICATOR
unset SNOWFLAKE_TOKEN
unset SNOWFLAKE_WAREHOUSE
unset SNOWSQL_WAREHOUSE

pushd "$PROJECT_ROOT/infra/remote/snowflake" >/dev/null

terraform init

import_if_exists() {
  local resource="$1"
  local remote_id="$2"

  if terraform state show "$resource" >/dev/null 2>&1; then
    echo "State already contains $resource"
    return 0
  fi

  echo "Attempting import: $resource <- $remote_id"
  if terraform import "$resource" "$remote_id" >/dev/null 2>&1; then
    echo "Imported: $resource"
  else
    echo "Not found or not importable now: $resource (will be created by terraform apply)"
  fi
}

import_if_exists snowflake_warehouse.weather_wh WEATHER_WH
import_if_exists snowflake_database.weather_analytics WEATHER_ANALYTICS
import_if_exists snowflake_schema.bronze "WEATHER_ANALYTICS.BRONZE"
import_if_exists snowflake_schema.silver "WEATHER_ANALYTICS.SILVER"
import_if_exists snowflake_schema.gold "WEATHER_ANALYTICS.GOLD"

terraform plan
terraform apply -auto-approve

popd >/dev/null

echo "Snowflake remote infrastructure created."
