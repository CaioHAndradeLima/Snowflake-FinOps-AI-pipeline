#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Creating User for Terraform application inside Snowflake..."
snowsql -f "$SCRIPT_DIR/roles.sql" -o log_level=DEBUG

echo "User: TERRAFORM_USER"
echo "Password: STRONG_P@SSW0RD123"
echo "Role: TERRAFORM_ROLE"

echo ""



