#!/usr/bin/env bash
set -euo pipefail

RUN_APPLY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR="$PROJECT_ROOT/infra/remote/aws/state-backend"
STATE_TFVARS="$STATE_DIR/terraform.tfvars"

echo "Provision AWS Terraform state backend"
echo "State directory: $STATE_DIR"

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is not installed."
  exit 1
fi

if [[ ! -f "$STATE_TFVARS" ]]; then
  echo "Error: missing $STATE_TFVARS"
  echo "Create it from example:"
  echo "cp $STATE_DIR/terraform.example.tfvars $STATE_TFVARS"
  exit 1
fi

pushd "$STATE_DIR" >/dev/null
terraform init
terraform plan -var-file=terraform.tfvars

if [[ "$RUN_APPLY" == "--apply" ]]; then
  terraform apply -auto-approve -var-file=terraform.tfvars
  terraform output
  echo "State backend provisioned."
else
  echo "Plan complete. Re-run with --apply to execute changes."
fi
popd >/dev/null
