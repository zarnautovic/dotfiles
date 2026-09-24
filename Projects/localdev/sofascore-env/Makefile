# Local dev tooling for SofaScore Web. Run these from THIS directory.
# The browser-facing app still runs on the remote dev server; everything
# else (composer / phpstan / cs-fixer / tests / console) runs locally here.

include .env
export

COMPOSE := docker compose -f compose.dev.yaml
EXEC    := $(COMPOSE) exec -u $(shell id -u):$(shell id -g) -w $(SOFASCORE_REPO) tools

# Test backing services come from the repo's OWN compose file, unchanged.
# (These docker commands must run on the host, not inside the container.)
TEST    := docker compose \
             --env-file $(SOFASCORE_REPO)/.env.test \
             --env-file $(SOFASCORE_REPO)/.env.test.local \
             -f $(SOFASCORE_REPO)/compose.test-local.yaml

.DEFAULT_GOAL := help

.PHONY: help build up down restart shell install phpstan cs test test-up test-down vscode

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

build: ## Build the tools image
	$(COMPOSE) build

up: ## Start the tools container (build if needed)
	$(COMPOSE) up -d --build

down: ## Stop & remove the tools container
	$(COMPOSE) down

restart: down up ## Recreate the tools container

shell: ## Interactive shell inside the tools container
	$(COMPOSE) exec -u $(shell id -u):$(shell id -g) -w $(SOFASCORE_REPO) tools bash

install: ## composer install (writes the gitignored vendor/)
	$(EXEC) composer install

phpstan: ## composer phpstan
	$(EXEC) composer phpstan

cs: ## php-cs-fixer — pass args, e.g. make cs ARGS="fix" or ARGS="fix --dry-run --diff"
	$(EXEC) composer linter -- $(ARGS)

test-up: ## Start test services (postgres/redis/es/beanstalk)
	$(TEST) up -d

test-down: ## Stop test services
	$(TEST) down

test: test-up ## Run the test suite (brings test services up first)
	$(EXEC) composer test

vscode: ## Render vscode/*.json into the repo's (gitignored) .vscode/ — skips existing files
	@mkdir -p $(SOFASCORE_REPO)/.vscode
	@for f in vscode/*.json; do \
		dst=$(SOFASCORE_REPO)/.vscode/$$(basename $$f); \
		if [ -e $$dst ]; then echo "skip   $$dst (exists)"; continue; fi; \
		sed -e "s#__REPO__#$(SOFASCORE_REPO)#g" -e "s#__ENV_DIR__#$(CURDIR)#g" $$f > $$dst; \
		echo "wrote  $$dst"; \
	done
