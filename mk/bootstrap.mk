.PHONY: setup install system-packages link link-linux link-macos _normalize-stow-state

setup: ## full bootstrap: system packages + mise tools + links + editor plugins + sheldon lock
	@$(MAKE) install
	@$(MAKE) link
	@$(MAKE) vim-plugins
	@$(MAKE) nvim-plugins
	@$(MAKE) sheldon
	$(SHELDON_BIN) lock

install: ## install system packages + mise-managed tools
	@$(MAKE) system-packages
	@$(MAKE) mise-tools

system-packages: ## install packages for the detected package manager
ifeq ($(PACKAGE_MANAGER),brew)
	@$(MAKE) brew
	@brew_bin="$$(command -v brew 2>/dev/null || true)"; \
	if [ -z "$$brew_bin" ]; then \
		for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do \
			if [ -x "$$candidate" ]; then \
				brew_bin="$$candidate"; \
				break; \
			fi; \
		done; \
	fi; \
	if [ -z "$$brew_bin" ]; then \
		echo "brew not found after installation"; \
		exit 1; \
	fi; \
	packages="$$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' $(BREW_PACKAGES_FILE))"; \
	if [ -n "$$packages" ]; then \
		"$$brew_bin" install $$packages; \
	fi
else ifeq ($(PACKAGE_MANAGER),apt)
	@packages="$$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' $(APT_PACKAGES_FILE))"; \
	if [ -z "$$packages" ]; then \
		echo "no apt packages configured"; \
		exit 0; \
	fi; \
	sudo apt-get update; \
	sudo apt-get install -y $$packages
else ifeq ($(PACKAGE_MANAGER),pacman)
	@packages="$$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' $(PACMAN_PACKAGES_FILE))"; \
	if [ -z "$$packages" ]; then \
		echo "no pacman packages configured"; \
		exit 0; \
	fi; \
	sudo pacman -S --needed $$packages
else
	@echo "unsupported package manager for $(PLATFORM)"; \
	echo "supported package managers: Homebrew, apt-get, pacman"; \
	exit 1
endif

link: _require-stow ## link dotfiles (auto-detect platform)
	@$(MAKE) _normalize-stow-state
	@echo "linking $(PLATFORM) packages: $(PACKAGES)"
	@for pkg in $(PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

link-linux: _require-stow ## force linux package set
	@$(MAKE) _normalize-stow-state
	@for pkg in $(LINUX_PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

link-macos: _require-stow ## force macos package set
	@$(MAKE) _normalize-stow-state
	@for pkg in $(MACOS_PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

_normalize-stow-state:
	@target="$(HOME)/.config/sheldon"; \
	expected="$(CURDIR)/zsh/.config/sheldon"; \
	if [ -L "$$target" ] && [ "$$(readlink "$$target")" = "$$expected" ]; then \
		echo "normalizing legacy absolute symlink $$target"; \
		rm "$$target"; \
	fi
