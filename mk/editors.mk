.PHONY: vim-plugins nvim-lazy nvim-plugins nvim-update _restore-lazy-nvim

nvim-lazy: _restore-lazy-nvim ## [network] restore only the pinned lazy.nvim checkout

vim-plugins: ## [network] install pinned vim-plug and sync Vim plugins
	@sh mk/vim-plugins.sh "$(CURDIR)" "$(HOME)" "$(VIM_PLUG_FILE)" "$(VIM_PLUGGED_DIR)" "$(DOWNLOAD_PINS_FILE)"

nvim-plugins: ## [network] restore Neovim plugins from the lock
	@if [ ! -f "$(NVIM_CONFIG_HOME)/init.lua" ]; then \
		echo "Neovim config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@if [ ! -f "$(CURDIR)/mk/verify-nvim-plugins.lua" ]; then \
		echo "Neovim verifier is missing: $(CURDIR)/mk/verify-nvim-plugins.lua"; \
		exit 1; \
	fi
	@sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" >/dev/null
	@$(MAKE) _restore-lazy-nvim
	@sh mk/nvim-plugins.sh "$(CURDIR)" "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" "$(LAZY_NVIM_LOCK_FILE)" "$(NVIM_TREESITTER_PARSERS)"

nvim-update: ## [network] update Neovim pins and show the lock diff
	@if [ ! -f "$(NVIM_CONFIG_HOME)/init.lua" ]; then \
		echo "Neovim config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" >/dev/null
	@$(MAKE) _restore-lazy-nvim
	@sh mk/nvim-update.sh "$(CURDIR)" "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" "$(LAZY_NVIM_LOCK_FILE)" "$(NVIM_TREESITTER_PARSERS)"

_restore-lazy-nvim:
	@sh mk/restore-lazy-nvim.sh "$(LAZY_NVIM_DIR)" "$(LAZY_NVIM_URL)" "$(LAZY_NVIM_COMMIT)" "$(LAZY_NVIM_LOCK_FILE)"
