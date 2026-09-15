.PHONY: clean

clean: _require-stow ## unstow platform-matched packages
	@echo "planning removal of $(PLATFORM) packages: $(PACKAGES)"
	@$(STOW) -n -v -D $(STOW_FLAGS) $(PACKAGES)
	@echo "unstowing $(PLATFORM) packages: $(PACKAGES)"
	@$(STOW) -D $(STOW_FLAGS) $(PACKAGES)
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents are unchanged; run 'make agents-disable-private' separately"; \
	fi
