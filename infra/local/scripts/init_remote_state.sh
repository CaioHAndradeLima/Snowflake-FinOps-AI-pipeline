#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: bash infra/local/scripts/init_remote_state.sh <aws-dev|aws-prod|snowflake-dev>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

case "$TARGET" in
  aws-dev)
    STACK_DIR="$PROJECT_ROOT/infra/remote/aws/environments/dev"
    BACKEND_FILE="$PROJECT_ROOT/infra/remote/backends/aws-dev.hcl"
    ;;
  aws-prod)
    STACK_DIR="$PROJECT_ROOT/infra/remote/aws/environments/prod"
    BACKEND_FILE="$PROJECT_ROOT/infra/remote/backends/aws-prod.hcl"
    ;;
  snowflake-dev)
    STACK_DIR="$PROJECT_ROOT/infra/remote/snowflake"
    BACKEND_FILE="$PROJECT_ROOT/infra/remote/backends/snowflake-dev.hcl"
    ;;
  *)
    echo "Invalid target: $TARGET"
    exit 1
    ;;
esac

if [[ ! -f "$BACKEND_FILE" ]]; then
  echo "Error: missing backend config file: $BACKEND_FILE"
  echo "Create it from the matching example file in infra/remote/backends/"
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is not installed."
  exit 1
fi

echo "Initializing remote state"
echo "Stack: $STACK_DIR"
echo "Backend config: $BACKEND_FILE"

terraform -chdir="$STACK_DIR" init -migrate-state -backend-config="$BACKEND_FILE"

echo "Remote state initialized for $TARGET"
