# Local dev tooling for SofaScore Web. Run these from THIS directory.
# The browser-facing app still runs on the remote dev server; everything
# else (composer / phpstan / cs-fixer / tests / console) runs locally here.

include .env
export

# Everything the image is built from is parsed out of the project repo, so
# `make up` follows the repo: PHP version + Debian release from the prod
# Dockerfile, extensions and system packages from docker/base/install.sh.
DOCKERFILE := $(SOFASCORE_REPO)/Dockerfile
INSTALL_SH := $(SOFASCORE_REPO)/docker/base/install.sh
PHP_VERSION                     := $(shell sed -n 's/^ARG PHP_VERSION=//p' $(DOCKERFILE))
PHP_EXTENSION_INSTALLER_VERSION := $(shell sed -n 's/^ARG PHP_EXTENSION_INSTALLER_VERSION=//p' $(DOCKERFILE))
PHP_DEBIAN                      := $(shell sed -n 's/^FROM php:.*-fpm-\([a-z]*\).*/\1/p' $(DOCKERFILE))
PHP_EXTENSIONS                  := $(shell sed -n 's/^install-php-extensions //p' $(INSTALL_SH))
IMAGEMAGICK_VERSION             := $(shell sed -n "s/^readonly IMAGEMAGICK_VERSION='\(.*\)'/\1/p" $(INSTALL_SH))
# URL of `curl ... /tmp/<name>.deb "<url>"` in install.sh, with its variables filled in.
deb_url = $(shell sed -n 's|.*/tmp/$(1)\.deb "\(.*\)".*|\1|p' $(INSTALL_SH) | \
            sed -e 's|\$${IMAGEMAGICK_VERSION}|$(IMAGEMAGICK_VERSION)|g' -e 's|\$${OS_CODENAME}|$(PHP_DEBIAN)|g')
IMAGEMAGICK_DEB_URL             := $(call deb_url,imagemagick)
WKHTMLTOX_DEB_URL               := $(call deb_url,wkhtmltox)

COMPOSE := docker compose -f compose.dev.yaml
EXEC    := $(COMPOSE) exec -u $(shell id -u):$(shell id -g) -w $(SOFASCORE_REPO) tools

# Test backing services come from the repo's OWN compose file, unchanged.
# (These docker commands must run on the host, not inside the container.)
TEST    := docker compose \
             --env-file $(SOFASCORE_REPO)/.env.test \
             --env-file $(SOFASCORE_REPO)/.env.test.local \
             -f $(SOFASCORE_REPO)/compose.test-local.yaml

.DEFAULT_GOAL := help

.PHONY: versions help build up down restart shell install phpstan cs test test-up test-down vscode doctor

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

build: ## Build the tools image from the repo's Dockerfile + docker/base/install.sh
	@$(MAKE) -s versions
	$(COMPOSE) build

up: ## Build (if the repo's versions changed) + (re)start the tools container
	@$(MAKE) -s versions
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

test-up: ## Start test services (postgres/redis/es/beanstalk) — also what `composer docker:test:up` runs
	$(TEST) up -d

test-down: ## Stop test services — also what `composer docker:test:down` runs
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

doctor: ## Check the local setup: container, PHP version/ini, platform reqs, test services
	@./doctor.sh

versions: ## Show what the image is built from (parsed from the project repo)
	@echo "PHP              $(PHP_VERSION) ($(PHP_DEBIAN))"
	@echo "ext installer    $(PHP_EXTENSION_INSTALLER_VERSION)"
	@echo "extensions       $(PHP_EXTENSIONS) imagick"
	@echo "ImageMagick      $(IMAGEMAGICK_VERSION)"
	@echo "wkhtmltox        $(notdir $(WKHTMLTOX_DEB_URL))"
