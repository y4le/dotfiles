.PHONY: mise mise-tools sheldon sheldon-plugins tmux-plugins brew

mise: ## [network] install the pinned, verified mise binary
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" sh mk/pinned.sh install mise "$(MISE_BIN)" 0755

mise-tools: mise ## [network] install tools from mise config
	MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) install

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
	mv "$$tmp" "$$cache"; \
	echo "wrote $$cache"

tmux-plugins: ## [network] restore tmux plugins at pinned commits
	@if ! command -v git >/dev/null 2>&1; then \
		echo "git not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@root="$(HOME)/.tmux/plugins"; \
	mkdir -p "$$root"; \
	while read -r name url commit extra || [ -n "$$name$$url$$commit$$extra" ]; do \
		case "$$name" in ''|'#'*) continue ;; esac; \
		if [ -n "$$extra" ] || [ -z "$$url" ] || [ -z "$$commit" ]; then \
			echo "invalid tmux plugin pin: $$name $$url $$commit $$extra"; \
			exit 1; \
		fi; \
		dir="$$root/$$name"; \
		if [ -e "$$dir" ] && [ ! -d "$$dir/.git" ]; then \
			echo "$$dir exists but is not a git checkout"; \
			exit 1; \
		fi; \
		if [ ! -d "$$dir/.git" ]; then \
			tmp="$$dir.tmp.$$$$"; \
			trap 'rm -rf "$$tmp"' EXIT; \
			trap 'rm -rf "$$tmp"; exit 1' HUP INT TERM; \
			git clone --no-checkout "$$url" "$$tmp" </dev/null || exit $$?; \
			git -c advice.detachedHead=false -C "$$tmp" checkout --detach "$$commit" </dev/null || exit $$?; \
			mv "$$tmp" "$$dir" || exit $$?; \
			trap - EXIT HUP INT TERM; \
		elif ! git -C "$$dir" cat-file -e "$$commit^{commit}" </dev/null 2>/dev/null; then \
			git -C "$$dir" fetch origin "$$commit" </dev/null || exit $$?; \
		fi; \
		git -c advice.detachedHead=false -C "$$dir" checkout --detach "$$commit" </dev/null || exit $$?; \
		actual="$$(git -C "$$dir" rev-parse HEAD </dev/null)" || exit 1; \
		if [ "$$actual" != "$$commit" ]; then \
			echo "$$name checkout mismatch: expected $$commit, got $$actual"; \
			exit 1; \
		fi; \
		echo "restored $$name at $$commit"; \
	done < "$(TMUX_PLUGIN_PINS_FILE)"

brew: ## [offline] report the Homebrew installation required by system-packages
ifeq ($(PLATFORM),macos)
	@brew_bin="$$(BREW_SEARCH_PATHS='$(BREW_SEARCH_PATHS)' sh mk/find-brew.sh)" || exit $$?; \
	echo "brew found at $$brew_bin"
else
	@echo "brew target is macOS only — use your system package manager on Linux"
endif
