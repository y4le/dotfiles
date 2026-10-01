.PHONY: clean

KNOWN_CLEAN_PACKAGES := $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES) osx linux-desktop osx-desktop

clean: _require-stow ## [offline] unstow all known public packages
	@sh mk/select-mise.sh --clean "$(CURDIR)" "$(HOME)" "$(MISE_CONFIG_FILE)"
	@echo "planning removal of managed packages: $(KNOWN_CLEAN_PACKAGES)"
	@sh mk/unstow.sh --plan "$(CURDIR)" "$(HOME)" "$(STOW)" $(KNOWN_CLEAN_PACKAGES)
	@echo "unstowing managed packages: $(KNOWN_CLEAN_PACKAGES)"
	@restore_profile=no; \
	if sh mk/prepare-zprofile.sh --is-managed "$(HOME)" "$(CURDIR)"; then restore_profile=yes; fi; \
	sh mk/unstow.sh --apply "$(CURDIR)" "$(HOME)" "$(STOW)" $(KNOWN_CLEAN_PACKAGES) || exit $$?; \
	if [ "$$restore_profile" = yes ]; then \
		sh mk/prepare-zprofile.sh --restore "$(HOME)" "$(CURDIR)"; \
	fi
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents are unchanged; run 'make agents-disable-private' separately"; \
	fi
