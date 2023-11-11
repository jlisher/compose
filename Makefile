GITSHA := $(shell git rev-parse --short HEAD)
TAG = "docker-compose:alpine-$(GITSHA)"
GIT_VOLUME = "--volume=$(shell pwd)/.git:/code/.git"

DOCKERFILE ?="Dockerfile"
DOCKER_BUILD_TARGET ?="build"

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	BUILD_SCRIPT = linux
endif
ifeq ($(UNAME_S),Darwin)
	BUILD_SCRIPT = osx
endif

RM := $(shell type -p rm)
RM_R := $(RM) -rf

INSTALL := $(shell type -p install)
INSTALL_EXEC := $(INSTALL) -Dm 0755
INSTALL_DATA := $(INSTALL) -Dm 0644

INSTALL_DIR ?= $(DESTDIR)$(PREFIX)
INSTALL_BINDIR ?= $(INSTALL_DIR)/bin
INSTALL_DATADIR ?= $(INSTALL_DIR)/share

COMPOSE_SPEC_SCHEMA_PATH = "compose/config/compose_spec.json"
COMPOSE_SPEC_RAW_URL = "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"

all: cli

cli: download-compose-spec ## Compile the cli
	./script/build/$(BUILD_SCRIPT)

simple: download-compose-spec commit-hash ## Compile the cli on current system
	./script/build/simple

install: ## Install the docker-compose cli binary
	$(INSTALL_EXEC) -t "$(INSTALL_BINDIR)" dist/docker-compose

install-completions: ## Install the docker-compose completions
	$(INSTALL_DATA) -t "$(INSTALL_DATADIR)/bash-completion/completions" contrib/completion/bash/docker-compose
	$(INSTALL_DATA) -t "$(INSTALL_DATADIR)/zsh/site-functions" contrib/completion/zsh/_docker-compose
	$(INSTALL_DATA) -t "$(INSTALL_DATADIR)/fish/vendor_completions.d" contrib/completion/fish/docker-compose.fish

download-compose-spec: ## Download the compose-spec schema from it's repo
	curl -so $(COMPOSE_SPEC_SCHEMA_PATH) $(COMPOSE_SPEC_RAW_URL)

commit-hash: ## Update GITSHA file for pyinstaller
	echo "$(GITSHA)" >compose/GITSHA

cache-clear: ## Clear the builder cache
	@docker builder prune --force --filter type=exec.cachemount --filter=unused-for=24h

base-image: ## Builds base image
	docker build -f $(DOCKERFILE) -t $(TAG) --target $(DOCKER_BUILD_TARGET) .

lint: base-image ## Run linter
	docker run --rm --tty $(GIT_VOLUME) $(TAG) tox -e pre-commit

test-unit: base-image ## Run tests
	docker run --rm --tty $(GIT_VOLUME) $(TAG) pytest -v tests/unit/

test: ## Run all tests
	./script/test/default

clean: ## Clean build files
	$(RM_R) dist/ build/ compose/GITSHA

pre-commit: lint test-unit cli

help: ## Show help
	@echo Please specify a build target. The choices are:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

FORCE:

.PHONY: all cli simple install install-completions download-compose-spec commit-hash cache-clear base-image lint test-unit test clean pre-commit help
