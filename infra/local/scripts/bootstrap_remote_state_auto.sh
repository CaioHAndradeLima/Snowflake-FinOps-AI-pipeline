#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR="$PROJECT_ROOT/infra/remote/aws/state-backend"
STATE_TFVARS="$STATE_DIR/terraform.tfvars"
BACKENDS_DIR="$PROJECT_ROOT/infra/remote/backends"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd"
    exit 1
  fi
}

write_file() {
  local path="$1"
  local content="$2"
  printf '%s\n' "$content" > "$path"
}

require_cmd aws
require_cmd terraform
require_cmd make

account_id="$(aws sts get-caller-identity --query Account --output text)"
region="${AWS_REGION:-$(aws configure get region || true)}"
region="${region:-us-east-1}"

bucket_name_default="snowflake-sentinel-tfstate-${account_id}-${region}"
lock_table_default="snowflake-sentinel-terraform-locks"

echo "Auto bootstrap remote Terraform state"
echo "Account: $account_id"
echo "Region: $region"
echo "State bucket: $bucket_name_default"
echo "Lock table: $lock_table_default"

mkdir -p "$STATE_DIR" "$BACKENDS_DIR"

write_file "$STATE_TFVARS" "aws_region          = \"$region\"
bucket_name         = \"$bucket_name_default\"
dynamodb_table_name = \"$lock_table_default\"
force_destroy       = false"

echo "Wrote: $STATE_TFVARS"

pushd "$PROJECT_ROOT" >/dev/null
make aws-state-backend-apply
popd >/dev/null

state_bucket="$(terraform -chdir="$STATE_DIR" output -raw state_bucket_name)"
lock_table="$(terraform -chdir="$STATE_DIR" output -raw lock_table_name)"

write_file "$BACKENDS_DIR/aws-dev.hcl" "bucket         = \"$state_bucket\"
key            = \"aws/dev/terraform.tfstate\"
region         = \"$region\"
dynamodb_table = \"$lock_table\"
encrypt        = true"

write_file "$BACKENDS_DIR/aws-prod.hcl" "bucket         = \"$state_bucket\"
key            = \"aws/prod/terraform.tfstate\"
region         = \"$region\"
dynamodb_table = \"$lock_table\"
encrypt        = true"

write_file "$BACKENDS_DIR/snowflake-dev.hcl" "bucket         = \"$state_bucket\"
key            = \"snowflake/dev/terraform.tfstate\"
region         = \"$region\"
dynamodb_table = \"$lock_table\"
encrypt        = true"

echo "Wrote backend files:"
echo " - $BACKENDS_DIR/aws-dev.hcl"
echo " - $BACKENDS_DIR/aws-prod.hcl"
echo " - $BACKENDS_DIR/snowflake-dev.hcl"

pushd "$PROJECT_ROOT" >/dev/null
make init-state-aws-dev
make init-state-aws-prod
make init-state-snowflake-dev
popd >/dev/null

echo "Remote state backend is fully initialized and migrated."
