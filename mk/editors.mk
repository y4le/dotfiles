.PHONY: vim-plugins nvim-lazy nvim-plugins nvim-update _restore-lazy-nvim

nvim-lazy: _restore-lazy-nvim ## [network] restore only the pinned lazy.nvim checkout

vim-plugins: ## [network] install pinned vim-plug and sync Vim plugins
	@if ! command -v vim >/dev/null 2>&1; then \
		echo "vim not found. Install it with your system package manager."; \
		exit 1; \
	fi
	@if [ ! -f "$(HOME)/.vim/config/plugins.vim" ]; then \
		echo "Vim config is not linked; run 'make link' first"; \
		exit 1; \
	fi
	@autoload_dir="$$(dirname "$(VIM_PLUG_FILE)")"; \
	case "$$autoload_dir" in \
		"$(CURDIR)"|"$(CURDIR)"/*) \
			echo "$$autoload_dir is inside the dotfiles repository; run 'make link' first"; \
			exit 1 ;; \
		*) ;; \
	esac; \
	if [ -L "$$autoload_dir" ]; then \
		echo "$$autoload_dir is a legacy or broken symlink; run 'make link' first"; \
		exit 1; \
	fi; \
	existing="$$autoload_dir"; \
	while [ ! -d "$$existing" ]; do \
		parent="$$(dirname "$$existing")"; \
		[ "$$parent" != "$$existing" ] || break; \
		existing="$$parent"; \
	done; \
	if [ -d "$$existing" ]; then \
		repo_physical="$$(cd -P "$(CURDIR)" && pwd -P)" || exit 1; \
		existing_physical="$$(cd -P "$$existing" && pwd -P)" || exit 1; \
		case "$$existing_physical/" in \
			"$$repo_physical/"*) \
				echo "$$autoload_dir would resolve into $$repo_physical (legacy folded layout)."; \
				echo "Remove the generated plug.vim, run 'make link', then rerun 'make vim-plugins'."; \
				exit 1 ;; \
			*) ;; \
		esac; \
	fi
	@DOTFILES_PINS_FILE="$(DOWNLOAD_PINS_FILE)" \
		sh mk/pinned.sh install vim-plug "$(VIM_PLUG_FILE)" 0644
	@fzf_dir="$(VIM_PLUGGED_DIR)/fzf"; \
	fzf_bin="$$fzf_dir/bin/fzf"; \
	if [ ! -L "$$fzf_dir" ] && [ -d "$$fzf_dir/.git" ] && [ ! -L "$$fzf_dir/.git" ] && \
		{ [ -e "$$fzf_bin" ] || [ -L "$$fzf_bin" ]; }; then \
		tracked="$$(GIT_DIR="$$fzf_dir/.git" GIT_WORK_TREE="$$fzf_dir" \
			git --no-optional-locks --no-replace-objects -c core.fsmonitor=false \
				ls-files --stage -- bin/fzf)" || { \
				echo "could not inspect plugin-local fzf binary: $$fzf_bin"; \
				exit 1; \
			}; \
		if [ -z "$$tracked" ]; then \
			echo "removing plugin-local fzf override: $$fzf_bin (mise supplies fzf)"; \
			rm -f "$$fzf_bin"; \
		fi; \
	fi
	@bootstrap="$$(mktemp)"; \
	trap 'rm -f "$$bootstrap"' EXIT HUP INT TERM; \
		printf '%s\n' \
			'let $$VIMHOME = expand("~/.vim")' \
			'execute "set runtimepath^=" . fnameescape($$VIMHOME)' \
			'execute "source " . fnameescape($$VIMHOME . "/config/plugins.vim")' > "$$bootstrap"; \
		echo "syncing Vim plugins"; \
		DOTFILES_VERIFY_VIM_PLUGINS="$(CURDIR)/mk/verify-vim-plugins.vim" \
			vim -Nu NONE -n -S "$$bootstrap" '+PlugInstall --sync' \
			'+execute "source " . fnameescape($$DOTFILES_VERIFY_VIM_PLUGINS)' +qa

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
	@nvim_bin="$$(sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)")" || exit $$?; \
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
		DOTFILES_NVIM_PARSERS="$(NVIM_TREESITTER_PARSERS)" \
		DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="$(CURDIR)/mk/verify-nvim-parsers.lua" \
		DOTFILES_NVIM_VERIFY_SCRIPT="$(CURDIR)/mk/verify-nvim-plugins.lua" \
		"$$nvim_bin" --headless \
		"+lua require('lazy').restore({ wait = true, show = false })" \
		"+TSUpdateSync $(NVIM_TREESITTER_PARSERS)" \
		"+lua dofile(vim.env.DOTFILES_NVIM_PARSER_VERIFY_SCRIPT)" \
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
	@sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" >/dev/null
	@$(MAKE) _restore-lazy-nvim
	@nvim_bin="$$(sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)")" || exit $$?; \
	DOTFILES_NVIM_BOOTSTRAP=1 DOTFILES_NVIM_PARSERS="$(NVIM_TREESITTER_PARSERS)" \
		DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="$(CURDIR)/mk/verify-nvim-parsers.lua" \
		"$$nvim_bin" --headless "+Lazy! sync" \
		"+TSUpdateSync $(NVIM_TREESITTER_PARSERS)" \
		"+lua dofile(vim.env.DOTFILES_NVIM_PARSER_VERIFY_SCRIPT)" +qa || exit $$?; \
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
