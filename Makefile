SHELL := /bin/bash

.PHONY: env env-help tf-plan tf-apply local-up local-down local-ps local-logs local-shell-app local-shell-dbt local-shell-tf

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
