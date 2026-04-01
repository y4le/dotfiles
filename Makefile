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
include mk/cleanup.mk

.PHONY: help gdrive-auth gdrive gdrive-enable gdrive-disable gdrive-status

help: ## show this help
	@grep -h -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

# -- gdrive (opt-in, separate from setup) --------------------------------------

gdrive-auth: mise-tools ## configure rclone Google Drive remote (one-time)
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) exec -- rclone config

gdrive: mise-tools ## run a Google Drive bisync now
	@MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) exec -- $(HOME)/bin/gdrive-sync

gdrive-enable: _require-stow ## stow gdrive package and enable systemd timer
	@echo "stowing gdrive package"
	mkdir -p "$(HOME)/.config/systemd/user"
	$(STOW) -t $(HOME) gdrive
	systemctl --user daemon-reload
	systemctl --user enable --now gdrive-sync.timer
	@echo "gdrive sync enabled (15m interval)"

gdrive-disable: _require-stow ## disable systemd timer and unstow gdrive package
	-systemctl --user disable --now gdrive-sync.timer
	systemctl --user daemon-reload
	$(STOW) -D -t $(HOME) gdrive 2>/dev/null || true
	@echo "gdrive sync disabled"

gdrive-status: ## show gdrive sync status
	@if systemctl --user is-active gdrive-sync.timer >/dev/null 2>&1; then \
		echo "timer: active"; \
		systemctl --user list-timers gdrive-sync.timer --no-pager; \
	else \
		echo "timer: inactive"; \
	fi
	@if [ -f "$(HOME)/.config/gdrive-sync/config" ]; then \
		echo "config: $(HOME)/.config/gdrive-sync/config"; \
		cat "$(HOME)/.config/gdrive-sync/config"; \
	else \
		echo "config: not found (not opted in)"; \
	fi
