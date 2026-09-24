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

STOW := $(shell command -v stow 2>/dev/null)
STOW_FLAGS := --no-folding -d "$(CURDIR)" -t "$(HOME)"

PRIVATE_AGENTS_DIR := $(HOME)/dev/agents
PRIVATE_AGENTS_PACKAGE := agents

COMMON := agents atuin bash git herdr mise nvim scripts tmux vim zsh
LOCAL_PACKAGES := $(if $(wildcard local/.),local,)
MACOS_CORE := osx
LINUX_DESKTOP := linux-desktop
MACOS_DESKTOP := osx-desktop

LINUX_BASE_PACKAGES := $(COMMON) $(LOCAL_PACKAGES)
MACOS_BASE_PACKAGES := $(COMMON) $(LOCAL_PACKAGES) $(MACOS_CORE)
LINUX_DESKTOP_PACKAGES := $(LINUX_BASE_PACKAGES) $(LINUX_DESKTOP)
MACOS_DESKTOP_PACKAGES := $(MACOS_BASE_PACKAGES) $(MACOS_DESKTOP)

DESKTOP ?= 0
ifneq ($(DESKTOP),0)
  ifneq ($(DESKTOP),1)
    $(error DESKTOP must be 0 or 1 (got '$(DESKTOP)'))
  endif
endif
LINUX_PACKAGES := $(LINUX_BASE_PACKAGES) $(if $(filter 1,$(DESKTOP)),$(LINUX_DESKTOP),)
MACOS_PACKAGES := $(MACOS_BASE_PACKAGES) $(if $(filter 1,$(DESKTOP)),$(MACOS_DESKTOP),)

ifeq ($(PLATFORM),macos)
  PACKAGES := $(MACOS_PACKAGES)
else
  PACKAGES := $(LINUX_PACKAGES)
endif

GUARDED_LINK_PACKAGES = $(filter-out local,$(LINK_PACKAGES))

SHELDON_BIN := $(HOME)/.local/bin/sheldon
SHELDON_CONFIG_FILE ?= $(HOME)/.config/sheldon/plugins.toml
SHELDON_DATA_DIR    ?= $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)/sheldon

MISE_BIN            := $(HOME)/.local/bin/mise
MISE_CONFIG_FILE    := $(CURDIR)/mise/.config/mise/config.toml
DOWNLOAD_PINS_FILE  := setup/pins/downloads.txt
HERDR_BIN           := $(HOME)/.local/bin/herdr
HERDR_CONFIG_FILE   := $(CURDIR)/herdr/.config/herdr/config.toml
HERDR_INTEGRATIONS  := claude codex antigravity-cli

VIM_PLUG_FILE       := $(HOME)/.vim/autoload/plug.vim
VIM_PLUGGED_DIR     := $(HOME)/.local/share/vim/plugged
LAZY_NVIM_URL       := https://github.com/folke/lazy.nvim.git
NVIM_DATA_HOME      := $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)/nvim
NVIM_CONFIG_HOME    := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/nvim
LAZY_NVIM_DIR       := $(NVIM_DATA_HOME)/lazy/lazy.nvim
LAZY_NVIM_LOCK_FILE := nvim/.config/nvim/lazy-lock.json
LAZY_NVIM_COMMIT    := $(shell awk -F '"' '/^  "lazy.nvim":/ { print $$10 }' $(LAZY_NVIM_LOCK_FILE))
NVIM_TREESITTER_PARSERS := bash json lua markdown markdown_inline python query rust toml tsx typescript vim vimdoc yaml

BREW_SEARCH_PATHS ?= /opt/homebrew/bin/brew /usr/local/bin/brew

PACKAGES_DIR         := setup/packages
BREW_PACKAGES_FILE   := $(PACKAGES_DIR)/brew.txt
APT_PACKAGES_FILE    := $(PACKAGES_DIR)/apt.txt
PACMAN_PACKAGES_FILE := $(PACKAGES_DIR)/pacman.txt
