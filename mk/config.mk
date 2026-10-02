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

BREW_SEARCH_PATHS ?= /opt/homebrew/bin/brew /usr/local/bin/brew
STOW := $(shell BREW_SEARCH_PATHS='$(BREW_SEARCH_PATHS)' sh mk/find-stow.sh '$(PLATFORM)')
STOW_FLAGS := --no-folding -d "$(CURDIR)" -t "$(HOME)"

PRIVATE_AGENTS_DIR := $(HOME)/dev/agents
PRIVATE_AGENTS_PACKAGE := agents

COMMON := $(PROFILE_PACKAGES)
UNSELECTED_PROFILE_PACKAGES = $(filter-out $(PACKAGES),$(KNOWN_PROFILE_PACKAGES))
LOCAL_PACKAGES := $(if $(wildcard local/.),local,)
MACOS_CORE := osx
LINUX_DESKTOP := linux-desktop
MACOS_DESKTOP := osx-desktop

LINUX_BASE_PACKAGES := $(COMMON) $(LOCAL_PACKAGES)
MACOS_BASE_PACKAGES := $(COMMON) $(LOCAL_PACKAGES) $(MACOS_CORE)
ifeq ($(origin DESKTOP),environment)
  DESKTOP := 0
endif
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
MISE_CONFIG_FILE    := $(CURDIR)/setup/tools.toml
DOWNLOAD_PINS_FILE  := setup/pins/downloads.txt
HERDR_BIN           := $(HOME)/.local/bin/herdr
HERDR_CONFIG_FILE   := $(CURDIR)/herdr/.config/herdr/config.toml
HERDR_INTEGRATIONS  := auto
# owner/repo@commit; keep vim-herdr-navigation in sync with the Vim and Neovim pins
HERDR_PLUGINS       := paulbkim-dev/vim-herdr-navigation@79679dacc791f70fc34de8b29a3cf9706c0f5b2f \
                       y4le/herdr-mark@bcd6458895f00b275a3429dd3b57a4e8124bdfac

VIM_PLUG_FILE       := $(HOME)/.vim/autoload/plug.vim
VIM_PLUGGED_DIR     := $(HOME)/.local/share/vim/plugged
LAZY_NVIM_URL       := https://github.com/folke/lazy.nvim.git
NVIM_DATA_HOME      := $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)/nvim
NVIM_CONFIG_HOME    := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/nvim
LAZY_NVIM_DIR       := $(NVIM_DATA_HOME)/lazy/lazy.nvim
LAZY_NVIM_LOCK_FILE := nvim/.config/nvim/lazy-lock.json
LAZY_NVIM_COMMIT    := $(shell awk -F '"' '/^  "lazy.nvim":/ { print $$10 }' $(LAZY_NVIM_LOCK_FILE))
NVIM_TREESITTER_PARSERS := bash json lua markdown markdown_inline python query rust toml tsx typescript vim vimdoc yaml

PACKAGES_DIR         := setup/packages
BREW_PACKAGES_FILE   := $(PACKAGES_DIR)/brew.txt
APT_PACKAGES_FILE    := $(PACKAGES_DIR)/apt.txt
PACMAN_PACKAGES_FILE := $(PACKAGES_DIR)/pacman.txt

# Optional explicit binary for rebuilding bundled fzf shell integration.
FZF_BIN ?=
