.PHONY: vim-bootstrap vim-plugins nvim-bootstrap nvim-plugins

vim-bootstrap: vim-plugins ## alias for vim-plugins

nvim-bootstrap: nvim-plugins ## alias for nvim-plugins

vim-plugins: $(VIM_PLUG_FILE) ## install vim-plug and sync Vim plugins
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

nvim-plugins: $(LAZY_NVIM_DIR) ## install lazy.nvim and sync Neovim plugins
	@ nvim_bin=""; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$nvim_bin" ]; then \
		nvim_bin="$$(command -v nvim 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$nvim_bin" ] || [ ! -x "$$nvim_bin" ]; then \
		echo "Neovim not found. Install it with 'make install'."; \
		exit 1; \
	fi; \
	echo "syncing Neovim plugins"; \
	"$$nvim_bin" --headless "+Lazy! sync" "+TSInstallSync $(NVIM_TREESITTER_PARSERS)" +qa

$(LAZY_NVIM_DIR):
	@if ! command -v git >/dev/null 2>&1; then \
		echo "git not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(dir $(LAZY_NVIM_DIR))
	git clone --filter=blob:none --branch=$(LAZY_NVIM_BRANCH) $(LAZY_NVIM_URL) $(LAZY_NVIM_DIR)

$(VIM_PLUG_FILE):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.vim/autoload
	curl -fLo $(VIM_PLUG_FILE) --create-dirs $(VIM_PLUG_URL)
