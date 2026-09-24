.PHONY: mise mise-tools herdr herdr-integrations sheldon sheldon-plugins brew

mise: ## [network] install the pinned, verified mise binary
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install mise "$(MISE_BIN)" 0755

mise-tools: mise ## [network] install tools from mise config
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) install

herdr: ## [network] install the pinned Herdr binary and validate its config
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install herdr "$(HERDR_BIN)" 0755
	@HERDR_CONFIG_PATH="$(HERDR_CONFIG_FILE)" "$(HERDR_BIN)" config check

herdr-integrations: ## [network] install selected Herdr agent integrations
ifeq ($(strip $(HERDR_INTEGRATIONS)),)
herdr-integrations:
	@echo "HERDR_INTEGRATIONS must name at least one integration"; \
	exit 1
else
herdr-integrations: herdr
	@set -eu; \
	for integration in $(HERDR_INTEGRATIONS); do \
		echo "installing Herdr integration: $$integration"; \
		"$(HERDR_BIN)" integration install "$$integration"; \
	done
endif

sheldon: ## [network] install the pinned, verified sheldon binary
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install sheldon "$(SHELDON_BIN)" 0755

sheldon-plugins: ## [network] restore pinned zsh plugins and build startup cache
	@if [ ! -x "$(SHELDON_BIN)" ]; then \
		echo "sheldon not found at $(SHELDON_BIN); run 'make tools' first"; \
		exit 1; \
	fi
	@if [ ! -f "$(SHELDON_CONFIG_FILE)" ]; then \
		echo "sheldon config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@cache="$${XDG_CACHE_HOME:-$(HOME)/.cache}/dotfiles/sheldon.zsh"; \
	dir="$$(dirname "$$cache")"; \
	tmp="$$cache.tmp.$$$$"; \
	trap 'rm -f "$$tmp"' EXIT; \
	trap 'rm -f "$$tmp"; exit 1' HUP INT TERM; \
	umask 077; \
	mkdir -p "$$dir"; \
	SHELDON_CONFIG_FILE="$(SHELDON_CONFIG_FILE)" SHELDON_DATA_DIR="$(SHELDON_DATA_DIR)" \
		"$(SHELDON_BIN)" lock || exit $$?; \
	SHELDON_CONFIG_FILE="$(SHELDON_CONFIG_FILE)" SHELDON_DATA_DIR="$(SHELDON_DATA_DIR)" \
		"$(SHELDON_BIN)" source > "$$tmp" || exit $$?; \
	if [ ! -s "$$tmp" ]; then \
		echo "sheldon produced an empty startup cache"; \
		exit 1; \
	fi; \
	sh mk/verify-sheldon-plugins.sh verify "$(SHELDON_CONFIG_FILE)" \
		"$(SHELDON_DATA_DIR)" "$$tmp" || exit $$?; \
	mv "$$tmp" "$$cache" || exit $$?; \
	echo "wrote $$cache"

brew: ## [offline] report the Homebrew installation required by system-packages
ifeq ($(PLATFORM),macos)
	@brew_bin="$$(BREW_SEARCH_PATHS='$(BREW_SEARCH_PATHS)' sh mk/find-brew.sh)" || exit $$?; \
	echo "brew found at $$brew_bin"
else
	@echo "brew target is macOS only — use your system package manager on Linux"
endif
