.PHONY: setup setup-user tools plugins system-packages plan link link-plan _link _link-plan _remove-legacy-functions _remove-legacy-ideavimrc _remove-legacy-vim-profiler _remove-legacy-tmux-config _remove-legacy-zsh-hooks _ensure-git-local-config _print-packages

setup: ## [sudo, network] full bootstrap including system packages
	@$(MAKE) system-packages
	@$(MAKE) setup-user

setup-user: ## [network] user-space tools, links, and plugins; no sudo
	@$(MAKE) tools
	@$(MAKE) link
	@$(MAKE) plugins

# Emit separate recursive recipe lines so Make preserves ordering and stops
# the phase on the first failed step. + keeps recursion active under make -n.
define run_setup_step
+@$(MAKE) $(1)

endef

tools: ## [network] install user-space tools
	$(foreach step,$(TOOL_STEPS),$(call run_setup_step,$(step)))

plugins: ## [network] restore shell, Vim, Neovim, and Herdr plugins
	$(foreach step,$(PLUGIN_STEPS),$(call run_setup_step,$(step)))

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
	sudo pacman -Syu --needed $$packages
else
	@echo "unsupported package manager for $(PLATFORM)"; \
	echo "supported package managers: Homebrew, apt-get, pacman"; \
	exit 1
endif

plan: ## [offline] preview selected tools, plugins, and link changes
	@$(MAKE) --no-print-directory profile
	@$(MAKE) --no-print-directory link-plan

link: ## [offline] link selected dotfiles and remove unselected add-on links
	@$(MAKE) --no-print-directory _link LINK_PACKAGES="$(PACKAGES)" REMOVE_PACKAGES="$(UNSELECTED_PROFILE_PACKAGES)"

link-plan: ## [offline] show link actions without changing anything
	@$(MAKE) --no-print-directory _link-plan LINK_PACKAGES="$(PACKAGES)" REMOVE_PACKAGES="$(UNSELECTED_PROFILE_PACKAGES)"

_link-plan: _require-stow
	@sh mk/report-dangling-links.sh "$(CURDIR)" "$(HOME)"
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
	@if [ -n "$(REMOVE_PACKAGES)" ]; then \
		echo "planning removal of unselected add-on links: $(REMOVE_PACKAGES)"; \
		sh mk/unstow.sh --plan "$(CURDIR)" "$(HOME)" "$(STOW)" $(REMOVE_PACKAGES) || exit $$?; \
	fi
	@echo "planning $(PLATFORM) packages: $(LINK_PACKAGES)"
	@repo_root="$$(CDPATH='' cd -- "$(CURDIR)" && pwd -P)" || exit 1; \
	atuin_dir="$$(CDPATH='' cd -- "$(HOME)/.config/atuin" 2>/dev/null && pwd -P)" || atuin_dir=; \
	if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' atuin ' && \
		[ -f "$(HOME)/.config/atuin/config.toml" ] && \
		[ ! -L "$(HOME)/.config/atuin/config.toml" ] && \
		[ "$$atuin_dir/config.toml" != "$$repo_root/atuin/.config/atuin/config.toml" ]; then \
		echo "cannot select Atuin: ~/.config/atuin/config.toml is a regular file" >&2; \
		echo "move it aside, then rerun 'make link-plan'" >&2; \
		exit 1; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' osx '; then \
		sh mk/prepare-zprofile.sh --plan "$(HOME)" "$(CURDIR)" || exit $$?; \
		set -- --ignore='^\.zprofile$$'; \
	else \
		set --; \
	fi; \
	sh mk/stow-plan.sh "$(PLAN_VERBOSE)" "$(STOW)" -n -v -R $(STOW_FLAGS) "$$@" $(LINK_PACKAGES)

_link: _link-plan
	@if [ -n "$(REMOVE_PACKAGES)" ]; then \
		echo "removing unselected add-on links: $(REMOVE_PACKAGES)"; \
		sh mk/unstow.sh --apply "$(CURDIR)" "$(HOME)" "$(STOW)" $(REMOVE_PACKAGES) || exit $$?; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' osx '; then \
		sh mk/prepare-zprofile.sh --apply "$(HOME)" "$(CURDIR)" || exit $$?; \
	fi
	@echo "linking $(PLATFORM) packages: $(LINK_PACKAGES)"
	@$(STOW) -R $(STOW_FLAGS) $(LINK_PACKAGES)
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' scripts '; then \
		$(MAKE) _remove-legacy-functions; \
	fi
	@if printf '%s\n' " $(LINK_PACKAGES) " | grep -q ' vim '; then \
		$(MAKE) _remove-legacy-ideavimrc _remove-legacy-vim-profiler; \
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
	@for name in cpst fzf_sources nav; do \
		sh mk/remove-legacy-link.sh "$(HOME)/.config/shell/functions/$$name" "$(CURDIR)" "scripts/.config/shell/functions/$$name" || exit $$?; \
	done
	@for name in compair.sh benchmark.sh; do \
		sh mk/remove-legacy-link.sh "$(HOME)/bin/$$name" "$(CURDIR)" "scripts/bin/$$name" || exit $$?; \
	done

_remove-legacy-ideavimrc:
	@sh mk/remove-legacy-link.sh "$(HOME)/.ideavimrc" "$(CURDIR)" "vim/.ideavimrc"

_remove-legacy-vim-profiler:
	@sh mk/remove-legacy-link.sh "$(HOME)/.vim/autoload/profiler.vim" "$(CURDIR)" "vim/.vim/autoload/profiler.vim"

_remove-legacy-zsh-hooks:
	@for entry in 'env.zsh .zshenv.local' 'pre.zsh .pre_profile' 'post.zsh .post_profile'; do \
		set -- $$entry; \
		if [ -f "$(HOME)/.config/zsh/hooks/$$1" ]; then \
			sh mk/remove-legacy-link.sh "$(HOME)/$$2" "$(CURDIR)" "local/$$2" || exit $$?; \
		fi; \
	done

_remove-legacy-tmux-config:
	@sh mk/remove-legacy-link.sh "$(HOME)/.tmux.conf" "$(CURDIR)" "tmux/.tmux.conf"

_ensure-git-local-config:
	@sh mk/remove-legacy-link.sh "$(HOME)/.gitconfig" "$(CURDIR)" "git/.gitconfig" || exit $$?; \
	target="$(HOME)/.gitconfig"; \
	if [ ! -e "$$target" ] && [ ! -L "$$target" ]; then \
		echo "creating local ~/.gitconfig for machine-specific identity"; \
		(umask 077; set -C; : > "$$target") || exit 1; \
	fi

_print-packages:
	@printf '%s\n' "$(PACKAGES)"
