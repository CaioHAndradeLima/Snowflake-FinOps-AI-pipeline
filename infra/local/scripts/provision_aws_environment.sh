#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
RUN_APPLY="${2:-}"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Usage: bash infra/local/scripts/provision_aws_environment.sh <dev|prod> [--apply]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_DIR="$PROJECT_ROOT/infra/remote/aws/environments/$ENVIRONMENT"

echo "Provision AWS environment: $ENVIRONMENT"
echo "Environment dir: $ENV_DIR"

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is not installed."
  exit 1
fi

if [[ ! -f "$ENV_DIR/terraform.tfvars" ]]; then
  echo "Error: missing $ENV_DIR/terraform.tfvars"
  echo "Create it from example:"
  echo "cp $ENV_DIR/terraform.example.tfvars $ENV_DIR/terraform.tfvars"
  exit 1
fi

pushd "$ENV_DIR" >/dev/null

terraform init
terraform plan -var-file="terraform.tfvars"

if [[ "$RUN_APPLY" == "--apply" ]]; then
  terraform apply -auto-approve -var-file="terraform.tfvars"
  terraform output
  echo "AWS $ENVIRONMENT resources applied."
else
  echo "Plan complete. Re-run with --apply to execute changes."
fi

popd >/dev/null
