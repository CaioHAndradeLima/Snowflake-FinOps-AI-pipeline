SHELL := /bin/bash

.PHONY: env env-help tf-plan tf-apply

ENV_FILE ?= infra/local/.env

env: ## Create one infra/local/.env with prod + dev vars
	@bash infra/local/scripts/generate-env.sh "$(ENV_FILE)"

env-help: ## Show env related targets
	@echo "make env               # writes infra/local/.env with prod + dev vars"
	@echo "make env ENV_FILE=..."

tf-plan: ## Run Terraform plan for Snowflake remote using infra/local/.env
	@bash infra/local/scripts/provision_snowflake_remote.sh

tf-apply: ## Run Terraform apply for Snowflake remote using infra/local/.env
	@bash infra/local/scripts/provision_snowflake_remote.sh --apply
