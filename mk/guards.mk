.PHONY: _require-stow

_require-stow:
	@if [ -z "$(STOW)" ]; then \
		echo "stow not found. Install it:"; \
		echo "  apt install stow      # Debian/Ubuntu"; \
		echo "  brew install stow     # macOS/Homebrew"; \
		echo "  pacman -S stow        # Arch"; \
		exit 1; \
	fi
	@stow_version="$$($(STOW) --version 2>/dev/null | awk 'NR == 1 { print $$NF }')"; \
	if ! $(STOW) --version 2>/dev/null | grep -q 'GNU Stow'; then \
		echo "unsupported stow implementation: $$($(STOW) --version 2>&1 | head -1)"; \
		echo "GNU Stow 2.3 or newer is required"; \
		exit 1; \
	fi; \
	case "$$stow_version" in \
		1.*|2.0.*|2.1.*|2.2.*) \
			echo "GNU Stow $$stow_version is too old; version 2.3 or newer is required"; \
			exit 1 \
			;; \
	esac
