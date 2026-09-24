SHELL = /bin/sh
.DEFAULT_GOAL := help

include mk/profiles.mk
include mk/config.mk
include mk/guards.mk
include mk/bootstrap.mk
include mk/tools.mk
include mk/editors.mk
include mk/agents.mk
include mk/cleanup.mk
include mk/checks.mk

.PHONY: help

help: ## [offline] show this help
	@grep -h -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'
