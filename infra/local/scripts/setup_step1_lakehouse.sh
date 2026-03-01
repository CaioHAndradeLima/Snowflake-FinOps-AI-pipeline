#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/infra/local/.env}"
RUN_EXPORT_NOW="${RUN_EXPORT_NOW:-true}"

usage() {
  echo "Usage: bash infra/local/scripts/setup_step1_lakehouse.sh [--setup-only]"
}

for arg in "$@"; do
  case "$arg" in
    --setup-only)
      RUN_EXPORT_NOW="false"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      usage
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

sync_snowflake_trust_to_aws() {
  local integration_name="$1"
  local env_tfvars="$2"
  local env_value="$3"
  local meta_sql meta_output sf_trusted_arn sf_external_id

  meta_sql="
DESC INTEGRATION ${integration_name};
SELECT \"property\", \"property_value\"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE \"property\" IN ('STORAGE_AWS_IAM_USER_ARN', 'STORAGE_AWS_EXTERNAL_ID');
"

  meta_output="$(snowsql -a "$SNOWFLAKE_ACCOUNT_IDENTIFIER" -u "$SNOWFLAKE_USER" -r "$SNOWFLAKE_ROLE_VALUE" -w "$SNOWFLAKE_WAREHOUSE_VALUE" -d "$SNOWFLAKE_DATABASE_VALUE" -s BRONZE -o output_format=tsv -o header=false -o friendly=false -o timing=false -o exit_on_error=true -q "$meta_sql")"

  sf_trusted_arn=""
  sf_external_id=""
  while IFS=$'\t' read -r raw_key raw_value; do
    key="$(printf '%s' "${raw_key:-}" | tr -d '"\r' | xargs | tr '[:lower:]' '[:upper:]')"
    value="$(printf '%s' "${raw_value:-}" | tr -d '\r' | sed 's/^"//; s/"$//' | xargs)"

    if [[ "$key" == "STORAGE_AWS_IAM_USER_ARN" ]]; then
      sf_trusted_arn="$value"
    elif [[ "$key" == "STORAGE_AWS_EXTERNAL_ID" ]]; then
      sf_external_id="$value"
    fi
  done <<< "$meta_output"

  if [[ -z "$sf_trusted_arn" || -z "$sf_external_id" ]]; then
    echo "Error: could not extract STORAGE_AWS_IAM_USER_ARN/STORAGE_AWS_EXTERNAL_ID from Snowflake integration $integration_name"
    echo "SnowSQL raw output:"
    printf '%s\n' "$meta_output"
    exit 1
  fi

  upsert_tfvar_string "$env_tfvars" "snowflake_trusted_principal_arn" "$sf_trusted_arn"
  upsert_tfvar_string "$env_tfvars" "snowflake_external_id" "$sf_external_id"
  echo "Updated $env_tfvars with Snowflake trust values."

  if [[ "$env_value" == "dev" ]]; then
    make -C "$PROJECT_ROOT" aws-dev-apply
  else
    make -C "$PROJECT_ROOT" aws-prod-apply
  fi
}

get_tf_output_raw() {
  local dir="$1"
  local name="$2"
  local expected_regex="${3:-}"
  local out_file err_file value
  out_file="$(mktemp)"
  err_file="$(mktemp)"

  if ! terraform -chdir="$dir" output -raw "$name" >"$out_file" 2>"$err_file"; then
    echo "Error: failed reading Terraform output '$name' from $dir"
    cat "$err_file"
    rm -f "$out_file" "$err_file"
    exit 1
  fi

  value="$(tr -d '\r' <"$out_file" | xargs)"
  if [[ -z "$value" || "$value" == *"Warning:"* || "$value" == *"No outputs found"* ]]; then
    echo "Error: Terraform output '$name' is empty in $dir."
    echo "Run: make aws-${APP_ENV_VALUE}-apply"
    rm -f "$out_file" "$err_file"
    exit 1
  fi

  if [[ -n "$expected_regex" ]] && [[ ! "$value" =~ $expected_regex ]]; then
    echo "Error: Terraform output '$name' has unexpected value: $value"
    echo "Expected pattern: $expected_regex"
    echo "Run: make aws-${APP_ENV_VALUE}-apply"
    rm -f "$out_file" "$err_file"
    exit 1
  fi

  rm -f "$out_file" "$err_file"
  printf '%s\n' "$value"
}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found at $ENV_FILE"
  echo "Run: make env"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_cmd terraform
require_cmd snowsql
require_cmd make

APP_ENV_VALUE="${APP_ENV:-dev}"
if [[ "$APP_ENV_VALUE" != "dev" && "$APP_ENV_VALUE" != "prod" ]]; then
  echo "Error: APP_ENV must be dev or prod in $ENV_FILE"
  exit 1
fi

if [[ "$APP_ENV_VALUE" == "dev" ]]; then
  AWS_ENV_DIR="$PROJECT_ROOT/infra/remote/aws/environments/dev"
  SNOWFLAKE_DATABASE_VALUE="${SNOWFLAKE_DATABASE_DEV:-${SNOWFLAKE_DATABASE:-SENTINEL}_DEV}"
  SNOWFLAKE_WAREHOUSE_VALUE="${SNOWFLAKE_WAREHOUSE_DEV:-${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL}_DEV}"
  SNOWFLAKE_ROLE_VALUE="${SNOWFLAKE_ROLE_DEV:-${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}"
else
  AWS_ENV_DIR="$PROJECT_ROOT/infra/remote/aws/environments/prod"
  SNOWFLAKE_DATABASE_VALUE="${SNOWFLAKE_DATABASE:-SENTINEL}"
  SNOWFLAKE_WAREHOUSE_VALUE="${SNOWFLAKE_WAREHOUSE:-WH_SENTINEL}"
  SNOWFLAKE_ROLE_VALUE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
fi

if [[ -z "${SNOWFLAKE_ACCOUNT:-}" || -z "${SNOWFLAKE_USER:-}" || -z "${SNOWFLAKE_PASSWORD:-}" ]]; then
  echo "Error: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER and SNOWFLAKE_PASSWORD are required in $ENV_FILE"
  exit 1
fi

SNOWFLAKE_ACCOUNT_IDENTIFIER="$SNOWFLAKE_ACCOUNT"
SNOWFLAKE_ORG_VALUE="${SNOWFLAKE_ORGANIZATION:-${SNOWFLAKE_ORGANIZATION_NAME:-}}"
if [[ "$SNOWFLAKE_ACCOUNT_IDENTIFIER" != *"-"* ]] && [[ -n "$SNOWFLAKE_ORG_VALUE" ]]; then
  SNOWFLAKE_ACCOUNT_IDENTIFIER="${SNOWFLAKE_ORG_VALUE}-${SNOWFLAKE_ACCOUNT_IDENTIFIER}"
fi

if [[ ! -f "$AWS_ENV_DIR/terraform.tfvars" ]]; then
  echo "Error: missing $AWS_ENV_DIR/terraform.tfvars"
  exit 1
fi
AWS_ENV_TFVARS="$AWS_ENV_DIR/terraform.tfvars"

INTEGRATION_ROLE_ARN="$(get_tf_output_raw "$AWS_ENV_DIR" "snowflake_integration_role_arn" '^arn:aws:iam::[0-9]{12}:role\/.+$')"
LAKEHOUSE_BUCKET_NAME="$(get_tf_output_raw "$AWS_ENV_DIR" "lakehouse_bucket_name" '^[a-z0-9.-]{3,63}$')"
ENV_UPPER="$(printf '%s' "$APP_ENV_VALUE" | tr '[:lower:]' '[:upper:]')"
INTEGRATION_NAME="${SNOWFLAKE_INTEGRATION_NAME:-SENTINEL_S3_INT_${ENV_UPPER}}"
STAGE_NAME="${SNOWFLAKE_STAGE_NAME:-ACCOUNT_USAGE_EXT_STAGE}"
FILE_FORMAT_NAME="${SNOWFLAKE_FILE_FORMAT_NAME:-FF_ACCOUNT_USAGE_PARQUET}"
STAGE_URL="s3://${LAKEHOUSE_BUCKET_NAME}/snowflake/${APP_ENV_VALUE}/account_usage/"

echo "Setting up Account Usage Export Pipeline objects"
echo "Environment: $APP_ENV_VALUE"
echo "Snowflake database: $SNOWFLAKE_DATABASE_VALUE"
echo "Snowflake role: $SNOWFLAKE_ROLE_VALUE"
echo "Snowflake warehouse: $SNOWFLAKE_WAREHOUSE_VALUE"
echo "Integration role ARN: $INTEGRATION_ROLE_ARN"
echo "Stage URL: $STAGE_URL"

export SNOWSQL_PWD="$SNOWFLAKE_PASSWORD"

BASE_SQL=$(cat <<SQL
USE ROLE ${SNOWFLAKE_ROLE_VALUE};
CREATE DATABASE IF NOT EXISTS ${SNOWFLAKE_DATABASE_VALUE};
USE DATABASE ${SNOWFLAKE_DATABASE_VALUE};
CREATE SCHEMA IF NOT EXISTS BRONZE;
USE SCHEMA BRONZE;

CREATE OR REPLACE STORAGE INTEGRATION ${INTEGRATION_NAME}
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '${INTEGRATION_ROLE_ARN}'
  STORAGE_ALLOWED_LOCATIONS = ('${STAGE_URL}');

CREATE OR REPLACE FILE FORMAT ${FILE_FORMAT_NAME}
  TYPE = PARQUET
  COMPRESSION = SNAPPY;

CREATE OR REPLACE STAGE ${STAGE_NAME}
  STORAGE_INTEGRATION = ${INTEGRATION_NAME}
  URL = '${STAGE_URL}'
  FILE_FORMAT = ${FILE_FORMAT_NAME};

CREATE OR REPLACE TASK EXPORT_QUERY_HISTORY_TO_S3_TASK
  WAREHOUSE = ${SNOWFLAKE_WAREHOUSE_VALUE}
  SCHEDULE = 'USING CRON 5 * * * * UTC'
AS
COPY INTO @${STAGE_NAME}/query_history/
FROM (
  SELECT
    QUERY_ID,
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    QUERY_TYPE,
    CAST(START_TIME AS TIMESTAMP_NTZ) AS START_TIME,
    CAST(END_TIME AS TIMESTAMP_NTZ) AS END_TIME,
    EXECUTION_STATUS,
    ERROR_CODE,
    ERROR_MESSAGE,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    CREDITS_USED_CLOUD_SERVICES,
    TOTAL_ELAPSED_TIME
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE START_TIME >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = PARQUET COMPRESSION = SNAPPY)
OVERWRITE = FALSE
SINGLE = FALSE;

CREATE OR REPLACE TASK EXPORT_WAREHOUSE_METERING_TO_S3_TASK
  WAREHOUSE = ${SNOWFLAKE_WAREHOUSE_VALUE}
  SCHEDULE = 'USING CRON 10 * * * * UTC'
AS
COPY INTO @${STAGE_NAME}/warehouse_metering/
FROM (
  SELECT
    CAST(START_TIME AS TIMESTAMP_NTZ) AS START_TIME,
    CAST(END_TIME AS TIMESTAMP_NTZ) AS END_TIME,
    WAREHOUSE_ID,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES
  FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
  WHERE START_TIME >= DATEADD('day', -2, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = PARQUET COMPRESSION = SNAPPY)
OVERWRITE = FALSE
SINGLE = FALSE;

ALTER TASK EXPORT_QUERY_HISTORY_TO_S3_TASK RESUME;
ALTER TASK EXPORT_WAREHOUSE_METERING_TO_S3_TASK RESUME;
SQL
)

snowsql -a "$SNOWFLAKE_ACCOUNT_IDENTIFIER" -u "$SNOWFLAKE_USER" -o exit_on_error=true -q "$BASE_SQL" >/dev/null
echo "Snowflake objects created and tasks resumed."

echo "Syncing Snowflake integration trust metadata back to AWS Terraform..."
sync_snowflake_trust_to_aws "$INTEGRATION_NAME" "$AWS_ENV_TFVARS" "$APP_ENV_VALUE"

if [[ "$RUN_EXPORT_NOW" == "true" ]]; then
  EXPORT_SQL=$(cat <<SQL
USE ROLE ${SNOWFLAKE_ROLE_VALUE};
USE DATABASE ${SNOWFLAKE_DATABASE_VALUE};
USE SCHEMA BRONZE;

COPY INTO @${STAGE_NAME}/query_history/
FROM (
  SELECT
    QUERY_ID,
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    QUERY_TYPE,
    CAST(START_TIME AS TIMESTAMP_NTZ) AS START_TIME,
    CAST(END_TIME AS TIMESTAMP_NTZ) AS END_TIME,
    EXECUTION_STATUS,
    ERROR_CODE,
    ERROR_MESSAGE,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    CREDITS_USED_CLOUD_SERVICES,
    TOTAL_ELAPSED_TIME
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = PARQUET COMPRESSION = SNAPPY)
OVERWRITE = FALSE
SINGLE = FALSE;

COPY INTO @${STAGE_NAME}/warehouse_metering/
FROM (
  SELECT
    CAST(START_TIME AS TIMESTAMP_NTZ) AS START_TIME,
    CAST(END_TIME AS TIMESTAMP_NTZ) AS END_TIME,
    WAREHOUSE_ID,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES
  FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
  WHERE START_TIME >= DATEADD('day', -2, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = PARQUET COMPRESSION = SNAPPY)
OVERWRITE = FALSE
SINGLE = FALSE;

LIST @${STAGE_NAME};
SQL
)
  snowsql -a "$SNOWFLAKE_ACCOUNT_IDENTIFIER" -u "$SNOWFLAKE_USER" -o exit_on_error=true -q "$EXPORT_SQL"
  echo "Initial export completed."
else
  echo "Setup completed. Skipped immediate export (--setup-only)."
fi
