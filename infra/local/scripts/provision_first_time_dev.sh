#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEV_ENV_DIR="$PROJECT_ROOT/infra/remote/aws/environments/dev"
DEV_TFVARS="$DEV_ENV_DIR/terraform.tfvars"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/infra/local/.env}"
INTEGRATION_NAME="${SNOWFLAKE_INTEGRATION_NAME_DEV:-SENTINEL_S3_INT_DEV}"
SKIP_SNOWFLAKE="false"

for arg in "$@"; do
  case "$arg" in
    --skip-snowflake)
      SKIP_SNOWFLAKE="true"
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: bash infra/local/scripts/provision_first_time_dev.sh [--skip-snowflake]"
      exit 1
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd"
    exit 1
  fi
}

normalize_principal_arn() {
  local arn="$1"
  if [[ "$arn" =~ ^arn:aws:sts::([0-9]{12}):assumed-role/([^/]+)/.+$ ]]; then
    echo "arn:aws:iam::${BASH_REMATCH[1]}:role/${BASH_REMATCH[2]}"
    return
  fi
  echo "$arn"
}

upsert_tfvar_string() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  local tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$escaped" '
    BEGIN { done = 0 }
    $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      print k " = \"" v "\""
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print k " = \"" v "\""
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

echo "First-time dev provisioning started"
echo "Project root: $PROJECT_ROOT"
echo "Dev tfvars: $DEV_TFVARS"

require_cmd aws
require_cmd terraform
require_cmd make

raw_arn="$(aws sts get-caller-identity --query Arn --output text)"
account_id="$(aws sts get-caller-identity --query Account --output text)"
trusted_arn="$(normalize_principal_arn "$raw_arn")"
temp_external_id="bootstrap-dev-${account_id}-$(date +%s)"

echo "AWS account: $account_id"
echo "AWS caller ARN: $raw_arn"
echo "Temporary trusted principal ARN: $trusted_arn"

if [[ ! -f "$DEV_TFVARS" ]]; then
  cp "$DEV_ENV_DIR/terraform.example.tfvars" "$DEV_TFVARS"
  echo "Created $DEV_TFVARS from example"
fi

upsert_tfvar_string "$DEV_TFVARS" "snowflake_trusted_principal_arn" "$trusted_arn"
upsert_tfvar_string "$DEV_TFVARS" "snowflake_external_id" "$temp_external_id"
echo "Updated dev tfvars with temporary trust values"

pushd "$PROJECT_ROOT" >/dev/null
make aws-bootstrap-apply
make aws-dev-apply
popd >/dev/null

role_arn="$(terraform -chdir="$DEV_ENV_DIR" output -raw snowflake_integration_role_arn)"
bucket_name="$(terraform -chdir="$DEV_ENV_DIR" output -raw lakehouse_bucket_name)"

echo "Dev AWS resources ready"
echo "Snowflake integration role ARN: $role_arn"
echo "Lakehouse bucket: $bucket_name"

if [[ "$SKIP_SNOWFLAKE" == "true" ]]; then
  echo "Skipped Snowflake integration finalization (--skip-snowflake)."
  exit 0
fi

require_cmd snowsql

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: missing env file at $ENV_FILE"
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

sf_org="${SNOWFLAKE_ORGANIZATION:-${SNOWFLAKE_ORGANIZATION_NAME:-}}"
sf_account_identifier="$SNOWFLAKE_ACCOUNT"
if [[ "$sf_account_identifier" != *"-"* ]] && [[ -n "$sf_org" ]]; then
  sf_account_identifier="${sf_org}-${sf_account_identifier}"
fi

sf_role="${SNOWFLAKE_ROLE_DEV:-${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}"
sf_wh="${SNOWFLAKE_WAREHOUSE_DEV:-${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL_DEV}}"
sf_db="${SNOWFLAKE_DATABASE_DEV:-${SNOWFLAKE_DATABASE:-SENTINEL_DEV}}"
sf_schema="${SNOWFLAKE_SCHEMA_DEV:-${SNOWFLAKE_SCHEMA:-PUBLIC}}"

export SNOWSQL_PWD="$SNOWFLAKE_PASSWORD"

create_sql="
CREATE OR REPLACE STORAGE INTEGRATION ${INTEGRATION_NAME}
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '${role_arn}'
  STORAGE_ALLOWED_LOCATIONS = ('s3://${bucket_name}/');
"

meta_sql="
DESC INTEGRATION ${INTEGRATION_NAME};
SELECT \"property\", \"property_value\"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE \"property\" IN ('STORAGE_AWS_IAM_USER_ARN', 'STORAGE_AWS_EXTERNAL_ID');
"

echo "Creating/refreshing Snowflake storage integration: $INTEGRATION_NAME"
snowsql -a "$sf_account_identifier" -u "$SNOWFLAKE_USER" -r "$sf_role" -w "$sf_wh" -d "$sf_db" -s "$sf_schema" -q "$create_sql" >/dev/null

meta_output="$(snowsql -a "$sf_account_identifier" -u "$SNOWFLAKE_USER" -r "$sf_role" -w "$sf_wh" -d "$sf_db" -s "$sf_schema" -o output_format=csv -o header=false -o friendly=false -o timing=false -q "$meta_sql")"

sf_trusted_arn="$(printf '%s\n' "$meta_output" | awk -F',' '$1=="STORAGE_AWS_IAM_USER_ARN"{print $2}' | tail -1 | tr -d '\r' | xargs)"
sf_external_id="$(printf '%s\n' "$meta_output" | awk -F',' '$1=="STORAGE_AWS_EXTERNAL_ID"{print $2}' | tail -1 | tr -d '\r' | xargs)"

if [[ -z "$sf_trusted_arn" || -z "$sf_external_id" ]]; then
  echo "Error: could not extract STORAGE_AWS_IAM_USER_ARN/STORAGE_AWS_EXTERNAL_ID from Snowflake."
  echo "Run manually in Snowflake: DESC INTEGRATION $INTEGRATION_NAME;"
  exit 1
fi

upsert_tfvar_string "$DEV_TFVARS" "snowflake_trusted_principal_arn" "$sf_trusted_arn"
upsert_tfvar_string "$DEV_TFVARS" "snowflake_external_id" "$sf_external_id"
echo "Updated dev tfvars with Snowflake trust values"

pushd "$PROJECT_ROOT" >/dev/null
make aws-dev-apply
popd >/dev/null

echo "First-time dev provisioning completed successfully."
