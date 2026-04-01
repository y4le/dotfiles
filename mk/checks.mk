.PHONY: check check-git check-shell check-stow check-make

check: check-git check-shell check-stow check-make ## run repo validation checks

check-git: ## check git diff for whitespace errors
	git diff --check

check-shell: ## syntax-check and lint tracked shell files
	@fail=0; \
	echo "check-shell: sh -n"; \
	for f in $(SH_FILES); do \
		sh -n "$$f" || fail=1; \
	done; \
	echo "check-shell: bash -n"; \
	for f in $(BASH_FILES); do \
		bash -n "$$f" || fail=1; \
	done; \
	echo "check-shell: zsh -n"; \
	for f in $(ZSH_FILES); do \
		zsh -n "$$f" || fail=1; \
	done; \
	if command -v shellcheck >/dev/null 2>&1; then \
		echo "check-shell: shellcheck"; \
		shellcheck -S warning -s sh $(SH_FILES) || fail=1; \
		shellcheck -S warning -s bash $(BASH_FILES) || fail=1; \
	else \
		echo "check-shell: shellcheck not found, skipping"; \
	fi; \
	if command -v shfmt >/dev/null 2>&1; then \
		echo "check-shell: shfmt -d"; \
		shfmt -d -ln posix $(SH_FILES) || fail=1; \
		shfmt -d -ln bash $(BASH_FILES) || fail=1; \
	else \
		echo "check-shell: shfmt not found, skipping"; \
	fi; \
	exit $$fail

check-stow: _require-stow ## dry-run stow package graphs in temp dirs
	@fail=0; \
	check_pkg_set() { \
		label="$$1"; \
		shift; \
		tmpdir=$$(mktemp -d); \
		echo "check-stow: $$label"; \
		if ! $(STOW) -n -t "$$tmpdir" "$$@" >/dev/null 2>&1; then \
			$(STOW) -n -t "$$tmpdir" "$$@" || fail=1; \
		fi; \
		rm -rf "$$tmpdir"; \
	}; \
	check_pkg_set "linux package set" $(LINUX_PACKAGES); \
	check_pkg_set "macos package set" $(MACOS_PACKAGES); \
	exit $$fail

check-make: ## dry-run make target graph and help output
	@echo "check-make: make -n setup"
	@$(MAKE) -n setup >/dev/null
	@echo "check-make: make -n link-linux"
	@$(MAKE) -n link-linux >/dev/null
	@echo "check-make: make -n link-macos"
	@$(MAKE) -n link-macos >/dev/null
	@echo "check-make: make -n nvim-plugins"
	@$(MAKE) -n nvim-plugins >/dev/null
	@echo "check-make: make help"
	@$(MAKE) help >/dev/null
