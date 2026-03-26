.POSIX:
SHELL = /bin/sh

# -- platform detection -------------------------------------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  PLATFORM := macos
else
  PLATFORM := linux
endif

ifeq ($(PLATFORM),macos)
  PACKAGE_MANAGER := brew
else ifneq ($(shell command -v apt-get 2>/dev/null),)
  PACKAGE_MANAGER := apt
else ifneq ($(shell command -v pacman 2>/dev/null),)
  PACKAGE_MANAGER := pacman
else
  PACKAGE_MANAGER := unknown
endif

# -- stow command detection ----------------------------------------------------

STOW := $(shell command -v xstow 2>/dev/null || command -v stow 2>/dev/null)

# -- package allowlists --------------------------------------------------------

COMMON  := agents bash git local mise nvim scripts tmux vim zsh
LINUX   := linux
MACOS   := osx

# -- computed package set ------------------------------------------------------

ifeq ($(PLATFORM),macos)
  PACKAGES := $(COMMON) $(MACOS)
else
  PACKAGES := $(COMMON) $(LINUX)
endif

# -- sheldon -------------------------------------------------------------------

SHELDON_BIN   := $(HOME)/.local/bin/sheldon
SHELDON_REPO  := rossmacarthur/sheldon
SHELDON_URL   := https://rossmacarthur.github.io/install/crate.sh

# -- mise ----------------------------------------------------------------------

MISE_BIN            := $(HOME)/.local/bin/mise
MISE_INSTALL_URL    := https://mise.run
MISE_CONFIG_FILE    := $(CURDIR)/mise/.config/mise/config.toml

# -- brew (macOS only) --------------------------------------------------------

BREW_INSTALL_URL := https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

# -- package lists -------------------------------------------------------------

PACKAGES_DIR        := setup/packages
BREW_PACKAGES_FILE  := $(PACKAGES_DIR)/brew.txt
APT_PACKAGES_FILE   := $(PACKAGES_DIR)/apt.txt
PACMAN_PACKAGES_FILE := $(PACKAGES_DIR)/pacman.txt

# -- targets -------------------------------------------------------------------

.PHONY: setup install system-packages mise mise-tools link link-linux link-macos sheldon brew clean help

help: ## show this help
	@grep -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

setup: ## full bootstrap: system packages + mise tools + links + sheldon lock
	@$(MAKE) install
	@$(MAKE) link
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

link-linux: _require-stow ## force linux package set
	@for pkg in $(COMMON) $(LINUX); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done

link-macos: _require-stow ## force macos package set
	@for pkg in $(COMMON) $(MACOS); do \
		echo "  stow $$pkg"; \
		$(STOW) -t $(HOME) $$pkg; \
	done

mise: $(MISE_BIN) ## install mise binary

$(MISE_BIN): _require-curl
	@mkdir -p $(HOME)/.local/bin
	curl -fsSL $(MISE_INSTALL_URL) | MISE_INSTALL_PATH=$(MISE_BIN) sh

mise-tools: mise ## install tools from mise config
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) install

sheldon: $(SHELDON_BIN) ## install sheldon binary

$(SHELDON_BIN): _require-curl
	@mkdir -p $(HOME)/.local/bin
	curl --proto '=https' -fLsS $(SHELDON_URL) | \
		bash -s -- --repo $(SHELDON_REPO) --to $(HOME)/.local/bin

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

clean: _require-stow ## unstow platform-matched packages
	@echo "unstowing $(PLATFORM) packages: $(PACKAGES)"
	@for pkg in $(PACKAGES); do \
		echo "  unstow $$pkg"; \
		$(STOW) -D -t $(HOME) $$pkg 2>/dev/null || true; \
	done

# -- internal ------------------------------------------------------------------

.PHONY: _require-stow

_require-stow:
	@if [ -z "$(STOW)" ]; then \
		echo "stow not found. Install it:"; \
		echo "  apt install stow      # Debian/Ubuntu"; \
		echo "  brew install stow     # macOS/Homebrew"; \
		echo "  pacman -S stow        # Arch"; \
		exit 1; \
	fi

.PHONY: _require-curl

_require-curl:
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
