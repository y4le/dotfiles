.PHONY: check check-actions check-git check-shell check-stow check-link check-make

check: check-git check-shell check-stow check-link check-make ## run repo validation checks

check-actions: ## lint GitHub Actions workflows
	@if ! command -v actionlint >/dev/null 2>&1; then \
		echo "actionlint not found. Install it to lint GitHub Actions workflows."; \
		exit 1; \
	fi
	@actionlint

check-git: ## check the tracked tree for whitespace errors
	@empty_tree="$$(git hash-object -t tree /dev/null)" || exit 1; \
	git diff --check "$$empty_tree"

check-shell: ## syntax-check and lint tracked shell files
	@fail=0; \
	sh_files="$$(git ls-files -z | xargs -0 awk \
		'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)(sh|dash)([[:space:]]|$$)/ { print FILENAME }')" || { \
		echo "check-shell: sh discovery failed"; \
		fail=1; \
	}; \
	bash_files="$$(git ls-files -z | xargs -0 awk \
		'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)bash([[:space:]]|$$)/ { print FILENAME }')" || { \
		echo "check-shell: bash discovery failed"; \
		fail=1; \
	}; \
	zsh_path_files="$$( \
		git ls-files -- \
			zsh/.zshenv \
			zsh/.zshrc \
			'zsh/.config/zsh/themes/*' \
			'*/.config/zsh/sources/*' \
			'*/.funcs/*' \
	)" || { \
		echo "check-shell: zsh path discovery failed"; \
		fail=1; \
	}; \
	zsh_shebang_files="$$( \
		git ls-files -z | xargs -0 awk \
			'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)zsh([[:space:]]|$$)/ { print FILENAME }' \
	)" || { \
		echo "check-shell: zsh shebang discovery failed"; \
		fail=1; \
	}; \
	zsh_files="$$( \
		printf '%s\n%s\n' "$$zsh_path_files" "$$zsh_shebang_files" | \
			sed '/^$$/d' | LC_ALL=C sort -u \
	)" || { \
		echo "check-shell: zsh list normalization failed"; \
		fail=1; \
	}; \
	for entry in "sh:$$sh_files" "bash:$$bash_files" "zsh:$$zsh_files"; do \
		label=$${entry%%:*}; \
		files=$${entry#*:}; \
		if [ -z "$$files" ]; then \
			echo "check-shell: no tracked $$label files discovered"; \
			fail=1; \
		fi; \
	done; \
	echo "check-shell: sh -n"; \
	for f in $$sh_files; do \
		sh -n "$$f" || fail=1; \
	done; \
	echo "check-shell: bash -n"; \
	for f in $$bash_files; do \
		bash -n "$$f" || fail=1; \
	done; \
	echo "check-shell: zsh -n"; \
	for f in $$zsh_files; do \
		zsh -n "$$f" || fail=1; \
	done; \
	if command -v shellcheck >/dev/null 2>&1; then \
		if [ -n "$$sh_files" ] && [ -n "$$bash_files" ]; then \
			echo "check-shell: shellcheck"; \
			shellcheck -S warning -s sh $$sh_files || fail=1; \
			shellcheck -S warning -s bash $$bash_files || fail=1; \
		fi; \
	else \
		echo "check-shell: shellcheck not found"; \
		if [ -n "$${CI:-}" ]; then \
			fail=1; \
		else \
			echo "check-shell: skipping shellcheck outside CI"; \
		fi; \
	fi; \
	exit $$fail

check-stow: _require-stow ## dry-run stow package graphs in temp dirs
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
	check_pkg_set "linux core package set" $(LINUX_BASE_PACKAGES); \
	check_pkg_set "linux desktop package set" $(LINUX_DESKTOP_PACKAGES); \
	check_pkg_set "macos core package set" $(MACOS_BASE_PACKAGES); \
	check_pkg_set "macos desktop package set" $(MACOS_DESKTOP_PACKAGES); \
	exit $$fail

check-link: ## test safe linking in isolated temporary homes
	@sh mk/test-link.sh

check-make: ## dry-run make target graph and help output
	@echo "check-make: make -n setup"
	@$(MAKE) -n setup >/dev/null
	@echo "check-make: make -n link-linux"
	@$(MAKE) -n link-linux >/dev/null
	@echo "check-make: make -n link-macos"
	@$(MAKE) -n link-macos >/dev/null
	@echo "check-make: make -n DESKTOP=1 link"
	@$(MAKE) -n DESKTOP=1 link >/dev/null
	@echo "check-make: reject invalid DESKTOP values"
	@if $(MAKE) -n DESKTOP=yes link >/dev/null 2>&1; then \
		echo "check-make: DESKTOP=yes was accepted"; \
		exit 1; \
	fi
	@echo "check-make: make -n link-plan"
	@$(MAKE) -n link-plan >/dev/null
	@echo "check-make: make -n clean"
	@$(MAKE) -n clean >/dev/null
	@echo "check-make: make -n nvim-plugins"
	@$(MAKE) -n nvim-plugins >/dev/null
	@echo "check-make: make help"
	@$(MAKE) help >/dev/null
