.PHONY: setup install system-packages link link-plan link-linux link-macos _link _link-plan _ensure-git-local-config _print-packages

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

link: ## link dotfiles (auto-detect platform)
	@$(MAKE) _link LINK_PACKAGES="$(PACKAGES)"

link-plan: ## show link actions without changing anything
	@$(MAKE) _link-plan LINK_PACKAGES="$(PACKAGES)"

link-linux: ## force linux package set
	@$(MAKE) _link LINK_PACKAGES="$(LINUX_PACKAGES)"

link-macos: ## force macos package set
	@$(MAKE) _link LINK_PACKAGES="$(MACOS_PACKAGES)"

_link-plan: _require-stow
	@if git -C "$(CURDIR)" rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		artifacts="$$(git -C "$(CURDIR)" ls-files --others -- $(GUARDED_LINK_PACKAGES))" || exit 1; \
		if [ -n "$$artifacts" ]; then \
			echo "untracked package files would be linked into HOME:"; \
			printf '  %s\n' $$artifacts; \
			echo "delete or move them before linking"; \
			exit 1; \
		fi; \
	else \
		echo "warning: artifact guard skipped; not a usable git checkout"; \
	fi
	@if [ -n "$${XDG_CONFIG_HOME:-}" ] && [ "$$XDG_CONFIG_HOME" != "$(HOME)/.config" ]; then \
		echo "warning: XDG_CONFIG_HOME=$$XDG_CONFIG_HOME differs from $(HOME)/.config"; \
	fi
	@echo "planning $(PLATFORM) packages: $(LINK_PACKAGES)"
	@$(STOW) -n -v -R $(STOW_FLAGS) $(LINK_PACKAGES)

_link: _link-plan
	@echo "linking $(PLATFORM) packages: $(LINK_PACKAGES)"
	@$(STOW) -R $(STOW_FLAGS) $(LINK_PACKAGES)
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' git '; then \
		$(MAKE) _ensure-git-local-config; \
	fi

_ensure-git-local-config:
	@target="$(HOME)/.gitconfig"; \
	legacy_parent="$$(cd "$(CURDIR)/git" && pwd -P)" || exit 1; \
	legacy="$$legacy_parent/.gitconfig"; \
	if [ -L "$$target" ]; then \
		link="$$(readlink "$$target")" || exit 1; \
		case "$$link" in \
			/*) linked_path="$$link" ;; \
			*) linked_path="$(HOME)/$$link" ;; \
		esac; \
		linked_parent="$$(cd "$$(dirname "$$linked_path")" 2>/dev/null && pwd -P)" || true; \
		if [ "$$linked_parent/$$(basename "$$linked_path")" = "$$legacy" ]; then \
			echo "replacing legacy managed ~/.gitconfig link with a local file"; \
			rm "$$target" || exit 1; \
		fi; \
	fi; \
	if [ ! -e "$$target" ] && [ ! -L "$$target" ]; then \
		echo "creating local ~/.gitconfig for machine-specific identity"; \
		(umask 077; set -C; : > "$$target") || exit 1; \
	fi

_print-packages:
	@printf '%s\n' "$(PACKAGES)"
