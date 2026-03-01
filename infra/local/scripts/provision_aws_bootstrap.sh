#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOOTSTRAP_DIR="$PROJECT_ROOT/infra/remote/aws/bootstrap"
RUN_APPLY="${1:-}"
AWS_REGION_VALUE="${AWS_REGION:-us-east-1}"

echo "Provision AWS bootstrap Terraform layer (execution roles)"
echo "Project root: $PROJECT_ROOT"
echo "Bootstrap dir: $BOOTSTRAP_DIR"
echo "AWS region: $AWS_REGION_VALUE"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd"
    exit 1
  fi
}

normalize_principal_arn() {
  local arn="$1"

  # Convert STS assumed-role ARN to IAM role ARN for trust policies.
  # arn:aws:sts::123456789012:assumed-role/RoleName/SessionName
  # -> arn:aws:iam::123456789012:role/RoleName
  if [[ "$arn" =~ ^arn:aws:sts::([0-9]{12}):assumed-role/([^/]+)/.+$ ]]; then
    echo "arn:aws:iam::${BASH_REMATCH[1]}:role/${BASH_REMATCH[2]}"
    return
  fi

  echo "$arn"
}

require_cmd aws
require_cmd terraform

pushd "$BOOTSTRAP_DIR" >/dev/null

raw_caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
account_id="$(aws sts get-caller-identity --query Account --output text)"
trusted_principal_arn="$(normalize_principal_arn "$raw_caller_arn")"

echo "AWS account: $account_id"
echo "Caller ARN: $raw_caller_arn"
echo "Trusted principal ARN: $trusted_principal_arn"

TMP_TFVARS="$(mktemp)"
trap 'rm -f "$TMP_TFVARS"' EXIT

cat > "$TMP_TFVARS" <<EOF
aws_region = "$AWS_REGION_VALUE"
trusted_principal_arns = ["$trusted_principal_arn"]
EOF

terraform init
terraform plan -var-file="$TMP_TFVARS"

if [[ "$RUN_APPLY" == "--apply" ]]; then
  terraform apply -auto-approve -var-file="$TMP_TFVARS"
  terraform output
  echo "AWS bootstrap roles created."
else
  echo "Plan complete. Re-run with --apply to create roles."
fi

popd >/dev/null
