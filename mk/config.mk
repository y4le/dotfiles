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

COMMON  := agents atuin bash git mise nvim scripts tmux vim zsh
LOCAL_PACKAGES := $(if $(wildcard local/.),local,)
LINUX   := linux
MACOS   := osx
LINUX_PACKAGES := $(COMMON) $(LOCAL_PACKAGES) $(LINUX)
MACOS_PACKAGES := $(COMMON) $(LOCAL_PACKAGES) $(MACOS)

ifeq ($(PLATFORM),macos)
  PACKAGES := $(MACOS_PACKAGES)
else
  PACKAGES := $(LINUX_PACKAGES)
endif

GUARDED_LINK_PACKAGES = $(filter-out local,$(LINK_PACKAGES))

SHELDON_BIN   := $(HOME)/.local/bin/sheldon
SHELDON_REPO  := rossmacarthur/sheldon
SHELDON_URL   := https://rossmacarthur.github.io/install/crate.sh

MISE_BIN            := $(HOME)/.local/bin/mise
MISE_INSTALL_URL    := https://mise.run
MISE_CONFIG_FILE    := $(CURDIR)/mise/.config/mise/config.toml

VIM_PLUG_URL        := https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
VIM_PLUG_FILE       := $(HOME)/.vim/autoload/plug.vim
LAZY_NVIM_URL       := https://github.com/folke/lazy.nvim.git
LAZY_NVIM_BRANCH    := stable
LAZY_NVIM_DIR       := $(HOME)/.local/share/nvim/lazy/lazy.nvim
NVIM_TREESITTER_PARSERS := bash json lua markdown markdown_inline python query rust toml tsx typescript vim vimdoc yaml

BREW_INSTALL_URL := https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

PACKAGES_DIR         := setup/packages
BREW_PACKAGES_FILE   := $(PACKAGES_DIR)/brew.txt
APT_PACKAGES_FILE    := $(PACKAGES_DIR)/apt.txt
PACMAN_PACKAGES_FILE := $(PACKAGES_DIR)/pacman.txt
