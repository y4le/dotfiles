.PHONY: setup setup-user install tools plugins system-packages link link-plan link-linux link-macos _link _link-plan _remove-legacy-functions _remove-legacy-ideavimrc _remove-legacy-tmux-config _remove-legacy-zsh-hooks _ensure-git-local-config _print-packages

setup: ## [sudo, network] full bootstrap including system packages
	@$(MAKE) system-packages
	@$(MAKE) setup-user

setup-user: ## [network] user-space tools, links, and plugins; no sudo
	@$(MAKE) tools
	@$(MAKE) link
	@$(MAKE) plugins

install: ## [sudo, network] compatibility alias: system packages + tools
	@$(MAKE) system-packages
	@$(MAKE) tools

tools: ## [network] install user-space tools
	@$(MAKE) mise-tools
	@$(MAKE) sheldon
	@$(MAKE) herdr

plugins: ## [network] restore shell, Vim, and Neovim plugins
	@$(MAKE) sheldon-plugins
	@$(MAKE) vim-plugins
	@$(MAKE) nvim-plugins

system-packages: ## [sudo, network] install native packages
ifeq ($(PACKAGE_MANAGER),brew)
	@brew_bin="$$(BREW_SEARCH_PATHS='$(BREW_SEARCH_PATHS)' sh mk/find-brew.sh)" || exit $$?; \
	packages="$$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' $(BREW_PACKAGES_FILE))"; \
	if [ -n "$$packages" ]; then \
		HOMEBREW_NO_AUTO_UPDATE=1 "$$brew_bin" install $$packages; \
	fi
else ifeq ($(PACKAGE_MANAGER),apt)
	@packages="$$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' $(APT_PACKAGES_FILE))"; \
	if [ -z "$$packages" ]; then \
		echo "no apt packages configured"; \
		exit 0; \
	fi; \
	sudo apt-get update && \
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

link: ## [offline] link dotfiles (auto-detect platform)
	@$(MAKE) _link LINK_PACKAGES="$(PACKAGES)"

link-plan: ## [offline] show link actions without changing anything
	@$(MAKE) _link-plan LINK_PACKAGES="$(PACKAGES)"

link-linux: ## [offline] force linux package set
	@$(MAKE) _link LINK_PACKAGES="$(LINUX_PACKAGES)"

link-macos: ## [offline] force macos package set
	@$(MAKE) _link LINK_PACKAGES="$(MACOS_PACKAGES)"

_link-plan: _require-stow
	@if git -C "$(CURDIR)" rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		artifacts="$$(git -C "$(CURDIR)" ls-files --others --directory --no-empty-directory -- $(GUARDED_LINK_PACKAGES))" || exit 1; \
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
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' scripts '; then \
		$(MAKE) _remove-legacy-functions; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' vim '; then \
		$(MAKE) _remove-legacy-ideavimrc; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' tmux '; then \
		$(MAKE) _remove-legacy-tmux-config; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' local '; then \
		$(MAKE) _remove-legacy-zsh-hooks; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' git '; then \
		$(MAKE) _ensure-git-local-config; \
	fi

_remove-legacy-functions:
	@for name in cpst fzf_sources nav y; do \
		sh mk/remove-legacy-link.sh "$(HOME)/.funcs/$$name" "$(CURDIR)" "scripts/.funcs/$$name" || exit $$?; \
	done
	@sh mk/remove-legacy-link.sh "$(HOME)/.funcs" "$(CURDIR)" "scripts/.funcs"
	@rmdir "$(HOME)/.funcs" 2>/dev/null || true

_remove-legacy-ideavimrc:
	@sh mk/remove-legacy-link.sh "$(HOME)/.ideavimrc" "$(CURDIR)" "vim/.ideavimrc"

_remove-legacy-zsh-hooks:
	@for entry in 'env.zsh .zshenv.local' 'pre.zsh .pre_profile' 'post.zsh .post_profile'; do \
		set -- $$entry; \
		if [ -f "$(HOME)/.config/zsh/hooks/$$1" ]; then \
			sh mk/remove-legacy-link.sh "$(HOME)/$$2" "$(CURDIR)" "local/$$2" || exit $$?; \
		fi; \
	done

_remove-legacy-tmux-config:
	@target="$(HOME)/.tmux.conf"; \
	legacy_parent="$$(cd "$(CURDIR)/tmux" && pwd -P)" || exit 1; \
	legacy="$$legacy_parent/.tmux.conf"; \
	if [ -L "$$target" ]; then \
		link="$$(readlink "$$target")" || exit 1; \
		case "$$link" in \
			/*) linked_path="$$link" ;; \
			*) linked_path="$(HOME)/$$link" ;; \
		esac; \
		linked_parent="$$(cd "$$(dirname "$$linked_path")" 2>/dev/null && pwd -P)" || true; \
		if [ "$$linked_parent/$$(basename "$$linked_path")" = "$$legacy" ]; then \
			echo "removing legacy managed ~/.tmux.conf link"; \
			rm "$$target" || exit 1; \
		fi; \
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
