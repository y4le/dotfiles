.PHONY: agents-enable-private agents-disable-private

agents-enable-private: _require-stow ## merge private agents into ~/.agents if present
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
	@touch "$(PRIVATE_AGENTS_DIR)/.stow"
	@echo "  stow $(PRIVATE_AGENTS_PACKAGE) from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)

agents-disable-private: _require-stow ## remove private agents from ~/.agents if present
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents package not found at $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE); nothing to do"; \
		exit 0; \
	fi
	@if [ ! -e "$(PRIVATE_AGENTS_DIR)/.stow" ]; then \
		touch "$(PRIVATE_AGENTS_DIR)/.stow"; \
	fi
	@echo "  unstow $(PRIVATE_AGENTS_PACKAGE) from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -D -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)
