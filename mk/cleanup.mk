.PHONY: clean

KNOWN_CLEAN_PACKAGES := $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES) osx linux-desktop osx-desktop

clean: _require-stow ## [offline] unstow all known public packages
	@echo "planning removal of managed packages: $(KNOWN_CLEAN_PACKAGES)"
	@$(STOW) -n -v -D $(STOW_FLAGS) $(KNOWN_CLEAN_PACKAGES)
	@echo "unstowing managed packages: $(KNOWN_CLEAN_PACKAGES)"
	@$(STOW) -D $(STOW_FLAGS) $(KNOWN_CLEAN_PACKAGES)
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents are unchanged; run 'make agents-disable-private' separately"; \
	fi
