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

STOW := $(shell command -v stow 2>/dev/null || command -v xstow 2>/dev/null)

PRIVATE_AGENTS_DIR := $(HOME)/dev/agents
PRIVATE_AGENTS_PACKAGE := agents

COMMON  := agents bash git local mise nvim scripts tmux vim zsh
LINUX   := linux
MACOS   := osx
LINUX_PACKAGES := $(COMMON) $(LINUX)
MACOS_PACKAGES := $(COMMON) $(MACOS)

ifeq ($(PLATFORM),macos)
  PACKAGES := $(MACOS_PACKAGES)
else
  PACKAGES := $(LINUX_PACKAGES)
endif

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

SH_FILES := linux/.xsessionrc scripts/bin/gdrive-sync
BASH_FILES := \
	linux/bin/i3_switch_workspaces.sh \
	scripts/bin/benchmark.sh \
	scripts/bin/compair.sh \
	scripts/bin/cpy \
	scripts/bin/filez \
	scripts/bin/pst \
	scripts/.funcs/cpst \
	scripts/.funcs/fzf_sources
ZSH_FILES := \
	local/.pre_profile \
	scripts/.funcs/cpst \
	scripts/.funcs/fzf_sources \
	scripts/.funcs/nav \
	taskwarrior/.config/zsh/sources/taskwarrior-aliases.zsh \
	zsh/.config/zsh/themes/minimal.zsh-theme \
	zsh/.zshenv \
	zsh/.zshrc
