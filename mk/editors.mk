.PHONY: vim-bootstrap vim-plugins nvim-bootstrap nvim-plugins nvim-update _restore-lazy-nvim

vim-bootstrap: vim-plugins ## [network] alias for vim-plugins

nvim-bootstrap: nvim-plugins ## [network] alias for nvim-plugins

vim-plugins: $(VIM_PLUG_FILE) ## [network] install vim-plug and sync Vim plugins
	@if ! command -v vim >/dev/null 2>&1; then \
		echo "vim not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@bootstrap="$$(mktemp)"; \
	trap 'rm -f "$$bootstrap"' EXIT HUP INT TERM; \
		printf '%s\n' \
			'let $$VIMHOME = expand("~/.vim")' \
			'execute "set runtimepath^=" . fnameescape($$VIMHOME)' \
			'execute "source " . fnameescape($$VIMHOME . "/config/plugins.vim")' > "$$bootstrap"; \
		echo "syncing Vim plugins"; \
		vim -Nu NONE -n -S "$$bootstrap" '+PlugInstall --sync' +qa

nvim-plugins: ## [network] restore Neovim plugins from the lock
	@if [ ! -f "$(NVIM_CONFIG_HOME)/init.lua" ]; then \
		echo "Neovim config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@if [ ! -f "$(CURDIR)/mk/verify-nvim-plugins.lua" ]; then \
		echo "Neovim verifier is missing: $(CURDIR)/mk/verify-nvim-plugins.lua"; \
		exit 1; \
	fi
	@nvim_bin=""; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$nvim_bin" ]; then \
		nvim_bin="$$(command -v nvim 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$nvim_bin" ] || [ ! -x "$$nvim_bin" ]; then \
		echo "Neovim not found. Install it with 'make tools'."; \
		exit 1; \
	fi
	@$(MAKE) _restore-lazy-nvim
	@nvim_bin=""; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$nvim_bin" ]; then \
		nvim_bin="$$(command -v nvim 2>/dev/null || true)"; \
	fi; \
	snapshot="$$(mktemp)" || exit 1; \
	if ! cp "$(LAZY_NVIM_LOCK_FILE)" "$$snapshot"; then \
		rm -f "$$snapshot"; \
		exit 1; \
	fi; \
	restore_lock() { \
		if [ -f "$$snapshot" ]; then \
			if cp "$$snapshot" "$(LAZY_NVIM_LOCK_FILE)"; then \
				rm -f "$$snapshot"; \
			else \
				echo "Could not restore the Neovim lock; saved copy: $$snapshot" >&2; \
				return 1; \
			fi; \
		fi; \
	}; \
	trap restore_lock EXIT; \
	trap 'restore_lock; exit 1' HUP INT TERM; \
	echo "restoring Neovim plugins"; \
	DOTFILES_NVIM_BOOTSTRAP=1 "$$nvim_bin" --headless \
		"+lua require('lazy').install({ wait = true, lockfile = true, show = false })" \
		+qa || exit $$?; \
	cp "$$snapshot" "$(LAZY_NVIM_LOCK_FILE)" || exit $$?; \
	DOTFILES_NVIM_BOOTSTRAP=1 DOTFILES_NVIM_LOCK_SNAPSHOT="$$snapshot" \
		DOTFILES_NVIM_VERIFY_SCRIPT="$(CURDIR)/mk/verify-nvim-plugins.lua" \
		"$$nvim_bin" --headless \
		"+lua require('lazy').restore({ wait = true, show = false })" \
		"+TSUpdateSync $(NVIM_TREESITTER_PARSERS)" \
		"+lua dofile(vim.env.DOTFILES_NVIM_VERIFY_SCRIPT)" +qa || exit $$?; \
	cmp -s "$$snapshot" "$(LAZY_NVIM_LOCK_FILE)" || { \
		diff -u "$$snapshot" "$(LAZY_NVIM_LOCK_FILE)" || true; \
		echo "Neovim restore changed the lock; update specs or run 'make nvim-update'"; \
		exit 1; \
	}

nvim-update: ## [network] update Neovim pins and show the lock diff
	@if [ ! -f "$(NVIM_CONFIG_HOME)/init.lua" ]; then \
		echo "Neovim config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@nvim_bin="$$(command -v nvim 2>/dev/null || true)"; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || printf '%s' "$$nvim_bin")"; \
	fi; \
	if [ -z "$$nvim_bin" ] || [ ! -x "$$nvim_bin" ]; then \
		echo "Neovim not found. Install it with 'make tools'."; \
		exit 1; \
	fi
	@$(MAKE) _restore-lazy-nvim
	@nvim_bin="$$(command -v nvim 2>/dev/null || true)"; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || printf '%s' "$$nvim_bin")"; \
	fi; \
	DOTFILES_NVIM_BOOTSTRAP=1 "$$nvim_bin" --headless "+Lazy! sync" \
		"+TSUpdateSync $(NVIM_TREESITTER_PARSERS)" +qa || exit $$?; \
	git diff --stat -- "$(LAZY_NVIM_LOCK_FILE)"

_restore-lazy-nvim:
	@if ! command -v git >/dev/null 2>&1; then \
		echo "git not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@if [ -z "$(LAZY_NVIM_COMMIT)" ]; then \
		echo "lazy.nvim pin missing from $(LAZY_NVIM_LOCK_FILE)"; \
		exit 1; \
	fi
	@dir="$(LAZY_NVIM_DIR)"; \
	mkdir -p "$$(dirname "$$dir")"; \
	if [ -e "$$dir" ] && [ ! -d "$$dir/.git" ]; then \
		echo "$$dir exists but is not a git checkout"; \
		exit 1; \
	fi; \
	if [ ! -d "$$dir/.git" ]; then \
		tmp="$$dir.tmp.$$$$"; \
		trap 'rm -rf "$$tmp"' EXIT; \
		trap 'rm -rf "$$tmp"; exit 1' HUP INT TERM; \
		git clone --no-checkout "$(LAZY_NVIM_URL)" "$$tmp" </dev/null || exit $$?; \
		git -c advice.detachedHead=false -C "$$tmp" checkout -q --detach "$(LAZY_NVIM_COMMIT)" </dev/null || exit $$?; \
		mv "$$tmp" "$$dir" || exit $$?; \
		trap - EXIT HUP INT TERM; \
	elif ! git -C "$$dir" cat-file -e "$(LAZY_NVIM_COMMIT)^{commit}" </dev/null 2>/dev/null; then \
		git -C "$$dir" fetch "$(LAZY_NVIM_URL)" "$(LAZY_NVIM_COMMIT)" </dev/null || exit $$?; \
	fi; \
	git -c advice.detachedHead=false -C "$$dir" checkout -q --detach "$(LAZY_NVIM_COMMIT)" </dev/null || exit $$?; \
	actual="$$(git -C "$$dir" rev-parse HEAD)" || exit 1; \
	if [ "$$actual" != "$(LAZY_NVIM_COMMIT)" ]; then \
		echo "lazy.nvim checkout mismatch: expected $(LAZY_NVIM_COMMIT), got $$actual"; \
		exit 1; \
	fi

$(VIM_PLUG_FILE):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.vim/autoload
	curl -fLo $(VIM_PLUG_FILE) --create-dirs $(VIM_PLUG_URL)
