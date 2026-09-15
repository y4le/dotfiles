.PHONY: agents-plan-private agents-enable-private agents-disable-private _require-private-agents

_require-private-agents: _require-stow
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)" ]; then \
		echo "private agents repo not found at $(PRIVATE_AGENTS_DIR)"; \
		echo "clone it there, then rerun 'make agents-enable-private'"; \
		exit 1; \
	fi
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents package not found at $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)"; \
		echo "expected layout: $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)/.agents/skills/"; \
		exit 1; \
	fi

agents-plan-private: _require-private-agents ## show private agent overlay actions
	@if git -C "$(PRIVATE_AGENTS_DIR)" rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		artifacts="$$(git -C "$(PRIVATE_AGENTS_DIR)" ls-files --others --directory --no-empty-directory -- "$(PRIVATE_AGENTS_PACKAGE)")" || exit 1; \
		if [ -n "$$artifacts" ]; then \
			echo "untracked private agent files would be linked into HOME:"; \
			printf '  %s\n' $$artifacts; \
			echo "track, delete, or move them before linking"; \
			exit 1; \
		fi; \
	else \
		echo "warning: private agent artifact guard skipped; not a usable git checkout"; \
	fi
	@echo "planning private agents from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -n -v -R --no-folding -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)

agents-enable-private: agents-plan-private ## merge private agents into ~/.agents
	@echo "linking private agents from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -R --no-folding -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)

agents-disable-private: _require-stow ## remove private agents from ~/.agents
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents package not found at $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE); nothing to do"; \
		echo "any dangling links must be removed manually"; \
	else \
		echo "planning private agent removal from $(PRIVATE_AGENTS_DIR)"; \
		$(STOW) -n -v -D --no-folding -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE) || exit $$?; \
		echo "removing private agents from $(PRIVATE_AGENTS_DIR)"; \
		$(STOW) -D --no-folding -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE); \
	fi
