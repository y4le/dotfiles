.PHONY: check check-actions check-git check-shell check-pins check-brew check-system-packages check-profiles check-vim check-nvim-first-open check-nvim-bin check-runtime check-stow check-link check-herdr check-make

check: check-git check-shell check-pins check-brew check-system-packages check-profiles check-vim check-nvim-bin check-runtime check-stow check-link check-herdr check-make ## [offline] run repo validation checks

check-profiles: ## [offline] validate setup profile selections and mise tool claims
	@sh mk/test-profiles.sh

check-actions: ## [offline] lint GitHub Actions workflows
	@if ! command -v actionlint >/dev/null 2>&1; then \
		echo "actionlint not found. Install it to lint GitHub Actions workflows."; \
		exit 1; \
	fi
	@actionlint

check-git: ## [offline] check the tracked tree for whitespace errors
	@empty_tree="$$(git hash-object -t tree /dev/null)" || exit 1; \
	git diff --check "$$empty_tree"
	@sh mk/test-git-pager.sh

check-shell: ## [offline] syntax-check and lint tracked shell files
	@sh mk/check-shell.sh

check-pins: ## [offline] validate download pins and the verified installer
	@sh mk/test-pins.sh
	@sh mk/test-sheldon-plugins.sh
	@sh mk/test-fzf.sh

check-brew: ## [offline] verify Homebrew remains an explicit prerequisite
	@sh mk/test-brew.sh

check-system-packages: ## [offline] verify native package command failure handling
	@sh mk/test-system-packages.sh

check-vim: ## [offline] validate portable Vim configuration behavior
	@sh mk/test-vim.sh
	@nvim_bin="$$(sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" 2>/dev/null || true)"; \
		DOTFILES_TEST_NVIM="$$nvim_bin" sh mk/test-clipboard.sh || exit $$?; \
		if [ -n "$$nvim_bin" ]; then \
		DOTFILES_REPO="$(CURDIR)" "$$nvim_bin" --headless -u NONE -i NONE -n -l mk/test-nvim-config.lua || exit $$?; \
		DOTFILES_REPO="$(CURDIR)" "$$nvim_bin" --headless -u NONE -i NONE -n -l mk/test-nvim-zoom.lua || exit $$?; \
		sh mk/test-nvim-editing.sh "$$nvim_bin" || exit $$?; \
		sh mk/test-nvim-setup.sh "$$nvim_bin"; \
	elif [ -n "$${CI:-}" ]; then \
		echo "check-vim: Neovim required in CI" >&2; exit 1; \
	fi

check-nvim-first-open: ## [offline] verify named files after Neovim plugins are restored
	@nvim_bin="$$(sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)")" || exit $$?; \
		sh mk/test-nvim-first-open.sh "$$nvim_bin"

check-nvim-bin: ## [offline] verify Neovim binary selection
	@sh mk/test-nvim-bin.sh
	@sh mk/test-mise-config.sh
	@sh mk/test-mise-selection.sh
	@nvim_bin="$$(sh mk/find-nvim.sh "$(MISE_BIN)" "$(MISE_CONFIG_FILE)" 2>/dev/null || true)"; \
		DOTFILES_TEST_NVIM="$$nvim_bin" sh mk/test-tool-availability.sh

check-runtime: ## [offline] verify shell startup stays usable and offline
	@sh mk/test-runtime.sh
	@sh mk/test-yazi.sh
	@bash mk/test-filez.sh
	@sh mk/test-cpst.sh
	@sh mk/test-i3blocks.sh
	@sh mk/test-mediaplayer.sh
	@sh mk/test-workspace-picker.sh
	@sh mk/test-xsession.sh

check-stow: _require-stow ## [offline] dry-run stow package graphs in temp dirs
	@fail=0; \
	check_pkg_set() { \
		label="$$1"; \
		shift; \
		tmpdir=$$(mktemp -d); \
		echo "check-stow: $$label"; \
		if ! $(STOW) -n -R --no-folding -d "$(CURDIR)" -t "$$tmpdir" "$$@" >/dev/null 2>&1; then \
			$(STOW) -n -R --no-folding -d "$(CURDIR)" -t "$$tmpdir" "$$@" || fail=1; \
		fi; \
		rm -rf "$$tmpdir"; \
	}; \
	check_pkg_set "linux core package set" $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES); \
	check_pkg_set "linux desktop package set" $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES) $(LINUX_DESKTOP); \
	check_pkg_set "macos core package set" $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES) $(MACOS_CORE); \
	check_pkg_set "macos desktop package set" $(KNOWN_PROFILE_PACKAGES) $(LOCAL_PACKAGES) $(MACOS_CORE) $(MACOS_DESKTOP); \
	exit $$fail

check-link: ## [offline] test safe linking in isolated temporary homes
	@sh mk/test-link.sh

check-herdr: ## [offline] test herdr-prefix switching against a stand-in Herdr
	@sh mk/test-herdr-prefix.sh

CHECK_MAKE = $(MAKE) PROFILE=full WITH=

check-make: ## [offline] dry-run make target graph and help output
	@echo "check-make: make -n setup"
	@$(CHECK_MAKE) -n PLATFORM=linux PACKAGE_MANAGER=apt setup >/dev/null
	@$(CHECK_MAKE) -n PLATFORM=macos PACKAGE_MANAGER=brew setup >/dev/null
	@$(CHECK_MAKE) -n PLATFORM=linux PACKAGE_MANAGER=pacman setup >/dev/null
	@setup_plan="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo setup )" || exit $$?; \
	expected="$$(printf '/bin/echo system-packages\nsystem-packages\n/bin/echo setup-user\nsetup-user')"; \
	if [ "$$setup_plan" != "$$expected" ]; then \
		echo "check-make: setup phase order changed"; exit 1; \
	fi
	@echo "check-make: make -n setup-user"
	@setup_user="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo setup-user )" || exit $$?; \
	expected="$$(printf '/bin/echo _mise-preflight\n_mise-preflight\n/bin/echo tools\ntools\n/bin/echo link\nlink\n/bin/echo plugins\nplugins')"; \
	if [ "$$setup_user" != "$$expected" ]; then \
		echo "check-make: setup-user phase order changed"; exit 1; \
	fi
	@setup_user_plan="$$( $(CHECK_MAKE) -n -s --no-print-directory setup-user )" || exit $$?; \
	setup_scripts="$$(cat mk/vim-plugins.sh mk/nvim-plugins.sh mk/nvim-update.sh mk/restore-lazy-nvim.sh mk/sheldon-plugins.sh)" || exit $$?; \
	if printf '%s\n%s\n' "$$setup_user_plan" "$$setup_scripts" | grep -Eq '^[[:space:]]*(sudo|doas)[[:space:]]|integration install'; then \
		echo "check-make: setup-user contains a privileged or opt-in integration command"; \
		exit 1; \
	fi
	@echo "check-make: make -n tools"
	@$(CHECK_MAKE) -n tools >/dev/null
	@echo "check-make: make -n herdr"
	@$(CHECK_MAKE) -n herdr >/dev/null
	@echo "check-make: make -n herdr-integrations"
	@$(CHECK_MAKE) -n herdr-integrations >/dev/null
	@echo "check-make: make -n plugins"
	@$(CHECK_MAKE) -n plugins >/dev/null
	@echo "check-make: tool and plugin phase order"
	@tools_plan="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo tools )" || exit $$?; \
	expected="$$(printf '/bin/echo mise-tools\nmise-tools\n/bin/echo sheldon\nsheldon\n/bin/echo herdr\nherdr')"; \
	if [ "$$tools_plan" != "$$expected" ]; then \
		echo "check-make: tools did not call mise-tools, sheldon, herdr in order"; \
		exit 1; \
	fi
	@plugin_plan="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo plugins )" || exit $$?; \
	expected="$$(printf '/bin/echo sheldon-plugins\nsheldon-plugins\n/bin/echo vim-plugins\nvim-plugins\n/bin/echo nvim-plugins\nnvim-plugins\n/bin/echo herdr-plugins\nherdr-plugins')"; \
	if [ "$$plugin_plan" != "$$expected" ]; then \
		echo "check-make: plugins did not restore shell, Vim, Neovim, Herdr in order"; \
		exit 1; \
	fi
	@echo "check-make: lite skips optional restore steps"
	@lite_tools="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo PROFILE=lite WITH= tools )" || exit $$?; \
	expected="$$(printf '/bin/echo mise-tools\nmise-tools\n/bin/echo sheldon\nsheldon')"; \
	if [ "$$lite_tools" != "$$expected" ]; then \
		echo "check-make: lite tool phases changed"; exit 1; \
	fi
	@lite_plugins="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo PROFILE=lite WITH= plugins )" || exit $$?; \
	expected="$$(printf '/bin/echo sheldon-plugins\nsheldon-plugins\n/bin/echo vim-plugins\nvim-plugins')"; \
	if [ "$$lite_plugins" != "$$expected" ]; then \
		echo "check-make: lite plugin phases changed"; exit 1; \
	fi
	@herdr_tools="$$( $(CHECK_MAKE) -n -s --no-print-directory MAKE=/bin/echo PROFILE=lite WITH=herdr tools )" || exit $$?; \
	printf '%s\n' "$$herdr_tools" | grep -Fxq 'herdr' || { \
		echo "check-make: herdr add-on did not enable its tool phase"; exit 1; \
	}
	@with_plugins="$$( $(MAKE) -n -s --no-print-directory MAKE=/bin/echo PROFILE=lite WITH='nvim herdr' plugins )" || exit $$?; \
	printf '%s\n' "$$with_plugins" | grep -Fxq 'nvim-plugins' || { \
		echo "check-make: nvim add-on did not enable plugins"; exit 1; \
	}
	@printf '%s\n' "$$( $(MAKE) -n -s --no-print-directory MAKE=/bin/echo PROFILE=lite WITH=herdr plugins )" | \
		grep -Fxq 'herdr-plugins' || { \
		echo "check-make: herdr add-on did not enable plugins"; exit 1; \
	}
	@echo "check-make: lite mise install selects only core pins"
	@mise_plan="$$( $(MAKE) -n -s --no-print-directory PROFILE=lite WITH= mise-tools )" || exit $$?; \
	lite_tools="$$(sh mk/profile.sh tools lite '')" || exit $$?; \
	printf '%s\n' "$$mise_plan" | grep -Fq " install $$lite_tools;" || { \
		echo "check-make: lite mise install did not name the selected core tools"; exit 1; \
	}
	@echo "check-make: make -n DESKTOP=1 link"
	@$(CHECK_MAKE) -n DESKTOP=1 link >/dev/null
	@echo "check-make: reject invalid DESKTOP values"
	@if $(CHECK_MAKE) -n DESKTOP=yes link >/dev/null 2>&1; then \
		echo "check-make: DESKTOP=yes was accepted"; \
		exit 1; \
	fi
	@echo "check-make: make -n link-plan"
	@$(CHECK_MAKE) -n link-plan >/dev/null
	@echo "check-make: make -n clean"
	@$(CHECK_MAKE) -n clean >/dev/null
	@echo "check-make: make -n nvim-plugins"
	@$(CHECK_MAKE) -n nvim-plugins >/dev/null
	@echo "check-make: make -n nvim-update"
	@$(CHECK_MAKE) -n nvim-update >/dev/null
	@echo "check-make: make -n nvim-lazy"
	@$(CHECK_MAKE) -n nvim-lazy >/dev/null
	@echo "check-make: make -n vim-plugins"
	@$(CHECK_MAKE) -n vim-plugins >/dev/null
	@echo "check-make: make -n sheldon-plugins"
	@$(CHECK_MAKE) -n sheldon-plugins >/dev/null
	@echo "check-make: make help"
	@help_output="$$( $(CHECK_MAKE) --no-print-directory help )" || exit $$?; \
	duplicates="$$(printf '%s\n' "$$help_output" | awk '{ if (seen[$$1]++) print $$1 }')"; \
	if [ -n "$$duplicates" ]; then \
		echo "check-make: duplicate help targets: $$duplicates"; \
		exit 1; \
	fi
