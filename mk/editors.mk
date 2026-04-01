.PHONY: vim-bootstrap vim-plugins

vim-bootstrap: vim-plugins ## alias for vim-plugins

vim-plugins: $(VIM_PLUG_FILE) ## install vim-plug and sync Vim/Neovim plugins
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
	vim -Nu NONE -n -S "$$bootstrap" '+PlugInstall --sync' +qa; \
	nvim_bin=""; \
	if [ -x "$(MISE_BIN)" ]; then \
		nvim_bin="$$(MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG_FILE) $(MISE_BIN) which nvim 2>/dev/null || true)"; \
	fi; \
	if [ -n "$$nvim_bin" ] && [ -x "$$nvim_bin" ]; then \
		echo "syncing Neovim plugins"; \
		"$$nvim_bin" --headless -u NONE -S "$$bootstrap" '+PlugInstall --sync' +qa; \
	else \
		echo "Neovim not available; skipping Neovim plugin sync"; \
	fi

$(VIM_PLUG_FILE):
	@if ! command -v curl >/dev/null 2>&1; then \
		echo "curl not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/.vim/autoload
	curl -fLo $(VIM_PLUG_FILE) --create-dirs $(VIM_PLUG_URL)
