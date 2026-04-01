.PHONY: _require-stow _require-curl

_require-stow:
	@if [ -z "$(STOW)" ]; then \
		echo "stow not found. Install it:"; \
		echo "  apt install stow      # Debian/Ubuntu"; \
		echo "  brew install stow     # macOS/Homebrew"; \
		echo "  pacman -S stow        # Arch"; \
		exit 1; \
	fi

_require-curl:
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
