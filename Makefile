.POSIX:
SHELL = /bin/sh
.DEFAULT_GOAL := help

include mk/config.mk
include mk/guards.mk
include mk/checks.mk
include mk/bootstrap.mk
include mk/tools.mk
include mk/editors.mk
include mk/agents.mk
include mk/optional.mk
include mk/cleanup.mk

.PHONY: help

help: ## show this help
	@grep -h -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'
