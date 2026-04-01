.PHONY: clean

clean: _require-stow ## unstow platform-matched packages
	@echo "unstowing $(PLATFORM) packages: $(PACKAGES)"
	@for pkg in $(PACKAGES); do \
		echo "  unstow $$pkg"; \
		$(STOW) -D -t $(HOME) $$pkg 2>/dev/null || true; \
	done
