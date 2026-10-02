.PHONY: mise mise-tools herdr herdr-integrations _herdr-integrations herdr-plugins sheldon sheldon-plugins brew

mise: ## [network] install the pinned, verified mise binary
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install mise "$(MISE_BIN)" 0755

mise-tools: mise ## [network] install tools from mise config
	@if [ -z "$(strip $(PROFILE_TOOLS))" ]; then \
		echo "no mise tools selected"; \
	else \
		MISE_CEILING_PATHS="$$(pwd -P)" \
		MISE_GLOBAL_CONFIG_FILE="$(MISE_CONFIG_FILE)" "$(MISE_BIN)" install $(PROFILE_TOOLS); \
	fi

herdr: ## [network] install the pinned Herdr binary and validate its config
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install herdr "$(HERDR_BIN)" 0755
	@HERDR_CONFIG_PATH="$(HERDR_CONFIG_FILE)" "$(HERDR_BIN)" config check

herdr-integrations: ## [network] preflight and install integrations for installed agents
	@selected="$$(sh mk/herdr-integrations.sh --select "$(CURDIR)" $(call profile_shell_quote,$(HERDR_INTEGRATIONS)))" || exit $$?; \
	if [ -z "$$selected" ]; then exit 0; fi; \
	$(MAKE) _herdr-integrations HERDR_SELECTED="$$selected"

# Keep mutations out of the recursive recipe above: Make runs recursive lines
# even under -n. This ordinary recipe is only printed during a dry run.
_herdr-integrations: herdr
	@sh mk/herdr-integrations.sh --install "$(CURDIR)" "$(HERDR_BIN)" "$(HERDR_SELECTED)"

herdr-plugins: ## [network] install pinned Herdr plugins
	@if [ ! -x "$(HERDR_BIN)" ]; then \
		echo "herdr not found at $(HERDR_BIN); run 'make tools' first"; \
		exit 1; \
	fi
	@if ! command -v jq >/dev/null 2>&1; then \
		echo "jq is required by Herdr plugins; run 'make system-packages' first"; \
		exit 1; \
	fi
	@set -eu; \
	installed="$$("$(HERDR_BIN)" plugin list)"; \
	for pin in $(HERDR_PLUGINS); do \
		source="$${pin%@*}"; \
		ref="$${pin#*@}"; \
		if printf '%s\n' "$$installed" | grep -Fq "[github:$$source@$$ref]"; then \
			echo "Herdr plugin current: $$source@$$ref"; \
			continue; \
		fi; \
		echo "installing Herdr plugin: $$source@$$ref"; \
		"$(HERDR_BIN)" plugin install "$$source" --ref "$$ref" --yes; \
	done

sheldon: ## [network] install the pinned, verified sheldon binary
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install sheldon "$(SHELDON_BIN)" 0755

sheldon-plugins: ## [network] restore pinned zsh plugins and build startup cache
	@sh mk/sheldon-plugins.sh "$(SHELDON_BIN)" "$(SHELDON_CONFIG_FILE)" "$(SHELDON_DATA_DIR)" "$(HOME)" "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" "$(FZF_BIN)"

brew: ## [offline] report the Homebrew installation required by system-packages
ifeq ($(PLATFORM),macos)
	@brew_bin="$$(BREW_SEARCH_PATHS='$(BREW_SEARCH_PATHS)' sh mk/find-brew.sh)" || exit $$?; \
	echo "brew found at $$brew_bin"
else
	@echo "brew target is macOS only — use your system package manager on Linux"
endif
