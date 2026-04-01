.POSIX:
SHELL = /bin/sh
.DEFAULT_GOAL := help

include mk/config.mk
include mk/guards.mk
include mk/checks.mk

.PHONY: help setup install system-packages mise mise-tools link link-linux link-macos agents-enable-private agents-disable-private sheldon vim-plugins vim-bootstrap brew clean gdrive-auth gdrive gdrive-enable gdrive-disable gdrive-status

help: ## show this help
	@grep -h -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

setup: ## full bootstrap: system packages + mise tools + links + editor plugins + sheldon lock
	@$(MAKE) install
	@$(MAKE) link
	@$(MAKE) vim-plugins
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
	@echo "linking $(PLATFORM) packages: $(PACKAGES)"
	@for pkg in $(PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

link-linux: _require-stow ## force linux package set
	@for pkg in $(LINUX_PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

link-macos: _require-stow ## force macos package set
	@for pkg in $(MACOS_PACKAGES); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done
	@if [ -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		$(MAKE) agents-enable-private; \
	fi

agents-enable-private: _require-stow ## merge private agents into ~/.agents if present
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)" ]; then \
		echo "private agents repo not found at $(PRIVATE_AGENTS_DIR)"; \
		echo "clone it there, then rerun 'make agents-enable-private'"; \
		exit 1; \
	fi
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents package not found at $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)"; \
		echo "expected layout: $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)/.agents/skills/"; \
		exit 1; \
	fi
	@touch "$(PRIVATE_AGENTS_DIR)/.stow"
	@echo "  stow $(PRIVATE_AGENTS_PACKAGE) from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)

agents-disable-private: _require-stow ## remove private agents from ~/.agents if present
	@if [ ! -d "$(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE)" ]; then \
		echo "private agents package not found at $(PRIVATE_AGENTS_DIR)/$(PRIVATE_AGENTS_PACKAGE); nothing to do"; \
		exit 0; \
	fi
	@if [ ! -e "$(PRIVATE_AGENTS_DIR)/.stow" ]; then \
		touch "$(PRIVATE_AGENTS_DIR)/.stow"; \
	fi
	@echo "  unstow $(PRIVATE_AGENTS_PACKAGE) from $(PRIVATE_AGENTS_DIR)"
	@$(STOW) -D -d "$(PRIVATE_AGENTS_DIR)" -t "$(HOME)" $(PRIVATE_AGENTS_PACKAGE)

mise: $(MISE_BIN) ## install mise binary

$(MISE_BIN):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.local/bin
	curl -fsSL $(MISE_INSTALL_URL) | MISE_INSTALL_PATH=$(MISE_BIN) sh

mise-tools: mise ## install tools from mise config
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) install

sheldon: $(SHELDON_BIN) ## install sheldon binary

$(SHELDON_BIN):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.local/bin
	curl --proto '=https' -fLsS $(SHELDON_URL) | \
		bash -s -- --repo $(SHELDON_REPO) --to $(HOME)/.local/bin

vim-bootstrap: vim-plugins ## alias for vim-plugins

vim-plugins: $(VIM_PLUG_FILE) ## install vim-plug and sync Vim/Neovim plugins
	@if ! command -v vim >/dev/null 2>&1; then \
		echo "vim not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@bootstrap="$$(mktemp)"; \
	trap 'rm -f "$$bootstrap"' EXIT HUP INT TERM; \
	printf '%s\n' \
		'let $$VIMHOME = expand("~/.vim")' \
		'execute "set runtimepath^=" . fnameescape($$VIMHOME)' \
		'execute "source " . fnameescape($$VIMHOME . "/config/plugins.vim")' > "$$bootstrap"; \
	echo "syncing Vim plugins"; \
	vim -Nu NONE -n -S "$$bootstrap" '+PlugInstall --sync' +qa; \
	nvim_bin=""; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || true)"; \
	fi; \
	if [ -n "$$nvim_bin" ] && [ -x "$$nvim_bin" ]; then \
		echo "syncing Neovim plugins"; \
		"$$nvim_bin" --headless -u NONE -S "$$bootstrap" '+PlugInstall --sync' +qa; \
	else \
		echo "Neovim not available; skipping Neovim plugin sync"; \
	fi

$(VIM_PLUG_FILE):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.vim/autoload
	curl -fLo $(VIM_PLUG_FILE) --create-dirs $(VIM_PLUG_URL)

brew: _require-curl ## install homebrew (macOS only)
ifeq ($(PLATFORM),macos)
	@if command -v brew >/dev/null 2>&1; then \
		echo "brew already installed at $$(command -v brew)"; \
	else \
		/bin/bash -c "$$(curl -fsSL $(BREW_INSTALL_URL))"; \
		brew_bin="$$(command -v brew 2>/dev/null || true)"; \
		if [ -z "$$brew_bin" ]; then \
			for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do \
				if [ -x "$$candidate" ]; then \
					brew_bin="$$candidate"; \
					break; \
				fi; \
			done; \
		fi; \
		echo ""; \
		if [ -n "$$brew_bin" ]; then \
			echo "brew installed at $$brew_bin"; \
			echo "add this to your shell init if brew is not already on PATH:"; \
			printf '  eval "$$(%s shellenv)"\n' "$$brew_bin"; \
		else \
			echo "brew installed, but the binary was not found on PATH yet"; \
		fi; \
	fi
else
	@echo "brew target is macOS only — use your system package manager on Linux"
endif

# -- gdrive (opt-in, separate from setup) --------------------------------------

gdrive-auth: mise-tools ## configure rclone Google Drive remote (one-time)
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) exec -- rclone config

gdrive: mise-tools ## run a Google Drive bisync now
	@MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) exec -- $(HOME)/bin/gdrive-sync

gdrive-enable: _require-stow ## stow gdrive package and enable systemd timer
	@echo "stowing gdrive package"
	mkdir -p "$(HOME)/.config/systemd/user"
	$(STOW) -t $(HOME) gdrive
	systemctl --user daemon-reload
	systemctl --user enable --now gdrive-sync.timer
	@echo "gdrive sync enabled (15m interval)"

gdrive-disable: _require-stow ## disable systemd timer and unstow gdrive package
	-systemctl --user disable --now gdrive-sync.timer
	systemctl --user daemon-reload
	$(STOW) -D -t $(HOME) gdrive 2>/dev/null || true
	@echo "gdrive sync disabled"

gdrive-status: ## show gdrive sync status
	@if systemctl --user is-active gdrive-sync.timer >/dev/null 2>&1; then \
		echo "timer: active"; \
		systemctl --user list-timers gdrive-sync.timer --no-pager; \
	else \
		echo "timer: inactive"; \
	fi
	@if [ -f "$(HOME)/.config/gdrive-sync/config" ]; then \
		echo "config: $(HOME)/.config/gdrive-sync/config"; \
		cat "$(HOME)/.config/gdrive-sync/config"; \
	else \
		echo "config: not found (not opted in)"; \
	fi

# -- cleanup -------------------------------------------------------------------

clean: _require-stow ## unstow platform-matched packages
	@echo "unstowing $(PLATFORM) packages: $(PACKAGES)"
	@for pkg in $(PACKAGES); do \
		echo "  unstow $$pkg"; \
		$(STOW) -D -t $(HOME) $$pkg 2>/dev/null || true; \
	done
