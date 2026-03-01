SHELL := /bin/bash

.PHONY: env env-help tf-plan tf-apply account-usage-export-setup account-usage-export-setup-only snowpark-ingestion-setup snowpark-ingestion-setup-only step1-lakehouse-setup step1-lakehouse-setup-only bootstrap-remote-state-auto init-state-aws-dev init-state-aws-prod init-state-snowflake-dev aws-state-backend-plan aws-state-backend-apply aws-bootstrap-plan aws-bootstrap-apply aws-dev-plan aws-dev-apply aws-prod-plan aws-prod-apply aws-first-time-dev aws-first-time-dev-no-snowflake dbt-run dbt-test local-up local-down local-ps local-logs local-shell-app local-shell-dbt local-shell-tf

ENV_FILE ?= infra/local/.env
DOCKER_COMPOSE := docker compose -f infra/local/docker-compose.yml

env: ## Create one infra/local/.env with prod + dev vars
	@bash infra/local/scripts/generate-env.sh "$(ENV_FILE)"

env-help: ## Show env related targets
	@echo "make env               # writes infra/local/.env with prod + dev vars"
	@echo "make env ENV_FILE=..."

tf-plan: ## Run Terraform plan for Snowflake remote using infra/local/.env
	@bash infra/local/scripts/provision_snowflake_remote.sh

tf-apply: ## Run Terraform apply for Snowflake remote using infra/local/.env
	@bash infra/local/scripts/provision_snowflake_remote.sh --apply

account-usage-export-setup: ## Create Snowflake->S3 export objects and run first export
	@bash infra/local/scripts/setup_step1_lakehouse.sh

account-usage-export-setup-only: ## Create Snowflake->S3 export objects only (no immediate export)
	@bash infra/local/scripts/setup_step1_lakehouse.sh --setup-only

snowpark-ingestion-setup: ## Step 2: create Snowpark ingestion procedure/task and run first ingest
	@bash infra/local/scripts/setup_step2_snowpark_ingestion.sh

snowpark-ingestion-setup-only: ## Step 2: create Snowpark ingestion procedure/task only
	@bash infra/local/scripts/setup_step2_snowpark_ingestion.sh --setup-only

# Backward-compatible aliases
step1-lakehouse-setup: account-usage-export-setup

step1-lakehouse-setup-only: account-usage-export-setup-only

bootstrap-remote-state-auto: ## One-command setup for Terraform remote state backend + migration
	@bash infra/local/scripts/bootstrap_remote_state_auto.sh

init-state-aws-dev: ## Initialize remote Terraform state for AWS dev stack
	@bash infra/local/scripts/init_remote_state.sh aws-dev

init-state-aws-prod: ## Initialize remote Terraform state for AWS prod stack
	@bash infra/local/scripts/init_remote_state.sh aws-prod

init-state-snowflake-dev: ## Initialize remote Terraform state for Snowflake dev stack
	@bash infra/local/scripts/init_remote_state.sh snowflake-dev

aws-state-backend-plan: ## Plan AWS state backend resources (S3 + DynamoDB)
	@bash infra/local/scripts/provision_aws_state_backend.sh

aws-state-backend-apply: ## Apply AWS state backend resources (S3 + DynamoDB)
	@bash infra/local/scripts/provision_aws_state_backend.sh --apply

aws-bootstrap-plan: ## Plan AWS bootstrap roles (TerraformExecutionRoleDev/Prod)
	@bash infra/local/scripts/provision_aws_bootstrap.sh

aws-bootstrap-apply: ## Apply AWS bootstrap roles (TerraformExecutionRoleDev/Prod)
	@bash infra/local/scripts/provision_aws_bootstrap.sh --apply

aws-dev-plan: ## Plan AWS dev environment resources
	@bash infra/local/scripts/provision_aws_environment.sh dev

aws-dev-apply: ## Apply AWS dev environment resources
	@bash infra/local/scripts/provision_aws_environment.sh dev --apply

aws-prod-plan: ## Plan AWS prod environment resources
	@bash infra/local/scripts/provision_aws_environment.sh prod

aws-prod-apply: ## Apply AWS prod environment resources
	@bash infra/local/scripts/provision_aws_environment.sh prod --apply

aws-first-time-dev: ## Full first-time dev setup (AWS + Snowflake trust finalization)
	@bash infra/local/scripts/provision_first_time_dev.sh

aws-first-time-dev-no-snowflake: ## First-time dev setup without Snowflake finalization
	@bash infra/local/scripts/provision_first_time_dev.sh --skip-snowflake

dbt-run: ## Run dbt models in local dbt container
	@$(DOCKER_COMPOSE) exec dbt dbt run --project-dir /workspace/dbt_project --profiles-dir /workspace/infra/local/dbt

dbt-test: ## Run dbt tests in local dbt container
	@$(DOCKER_COMPOSE) exec dbt dbt test --project-dir /workspace/dbt_project --profiles-dir /workspace/infra/local/dbt

local-up: ## Build and start local infra containers
	@$(DOCKER_COMPOSE) up -d --build

local-down: ## Stop and remove local infra containers
	@$(DOCKER_COMPOSE) down

local-ps: ## Show local infra container status
	@$(DOCKER_COMPOSE) ps

local-logs: ## Tail logs from local infra containers
	@$(DOCKER_COMPOSE) logs -f --tail=100

local-shell-app: ## Open shell in app container
	@$(DOCKER_COMPOSE) exec app bash

local-shell-dbt: ## Open shell in dbt container
	@$(DOCKER_COMPOSE) exec dbt bash

local-shell-tf: ## Open shell in terraform container
	@$(DOCKER_COMPOSE) exec terraform sh
