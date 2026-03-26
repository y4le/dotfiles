.POSIX:
SHELL = /bin/sh

# -- platform detection -------------------------------------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  PLATFORM := macos
else
  PLATFORM := linux
endif

# -- stow command detection ----------------------------------------------------

STOW := $(shell command -v xstow 2>/dev/null || command -v stow 2>/dev/null)

# -- package allowlists --------------------------------------------------------

COMMON  := agents alacritty bash git local pet scripts tmux vim zsh
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

# -- brew (macOS only) --------------------------------------------------------

BREW_INSTALL_URL := https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

# -- targets -------------------------------------------------------------------

.PHONY: setup install link link-linux link-macos sheldon brew clean help

help: ## show this help
	@grep -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

setup: _require-stow sheldon install link ## full bootstrap: deps + packages + links
	$(SHELDON_BIN) lock

install: ## install packages (brew on macOS, system pkg mgr on Linux)
ifeq ($(PLATFORM),macos)
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "brew not found — run 'make brew' first"; \
		exit 1; \
	fi
	bash setup/update_brew.sh
else
	@echo "Linux detected — install packages with your system package manager."
	@echo "See setup/update_brew.sh for the package list."
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

sheldon: $(SHELDON_BIN) ## install sheldon binary

$(SHELDON_BIN):
	@mkdir -p $(HOME)/.local/bin
	curl --proto '=https' -fLsS $(SHELDON_URL) | \
		bash -s -- --repo $(SHELDON_REPO) --to $(HOME)/.local/bin

brew: ## install homebrew (macOS only)
ifeq ($(PLATFORM),macos)
	@if command -v brew >/dev/null 2>&1; then \
		echo "brew already installed at $$(command -v brew)"; \
	else \
		/bin/bash -c "$$(curl -fsSL $(BREW_INSTALL_URL))"; \
		echo ""; \
		echo "brew installed. To use it in this shell, run:"; \
		echo "  eval \"\$$(brew shellenv 2>/dev/null || \
			/opt/homebrew/bin/brew shellenv 2>/dev/null || \
			/usr/local/bin/brew shellenv 2>/dev/null)\""; \
		echo "then re-run: make setup"; \
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
