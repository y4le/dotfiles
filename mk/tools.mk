.PHONY: mise mise-tools sheldon sheldon-plugins brew

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

sheldon-plugins: sheldon ## restore zsh plugins and build the startup cache
	@if [ ! -f "$(HOME)/.config/sheldon/plugins.toml" ]; then \
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
	"$(SHELDON_BIN)" lock || exit $$?; \
	"$(SHELDON_BIN)" source > "$$tmp" || exit $$?; \
	if [ ! -s "$$tmp" ]; then \
		echo "sheldon produced an empty startup cache"; \
		exit 1; \
	fi; \
	mv "$$tmp" "$$cache"; \
	echo "wrote $$cache"

$(SHELDON_BIN):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
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
