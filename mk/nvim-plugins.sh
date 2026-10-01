#!/bin/sh

set -eu

repo=$1
mise_bin=$2
mise_config=$3
lock_file=$4
parsers=$5

nvim_bin="$(sh mk/find-nvim.sh "${mise_bin}" "${mise_config}")" || exit $?
snapshot="$(mktemp)" || exit 1
if ! cp "${lock_file}" "$snapshot"; then
	rm -f "$snapshot"
	exit 1
fi
restore_lock() {
	if [ -f "$snapshot" ]; then
		if cp "$snapshot" "${lock_file}"; then
			rm -f "$snapshot"
		else
			echo "Could not restore the Neovim lock; saved copy: $snapshot" >&2
			return 1
		fi
	fi
}
trap restore_lock EXIT
trap 'restore_lock; exit 1' HUP INT TERM
echo "restoring Neovim plugins"
DOTFILES_NVIM_BOOTSTRAP=1 "$nvim_bin" --headless \
	"+lua require('lazy').install({ wait = true, lockfile = true, show = false })" \
	+qa || exit $?
cp "$snapshot" "${lock_file}" || exit $?
DOTFILES_NVIM_BOOTSTRAP=1 DOTFILES_NVIM_LOCK_SNAPSHOT="$snapshot" \
	DOTFILES_NVIM_PARSERS="${parsers}" \
	DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="${repo}/mk/verify-nvim-parsers.lua" \
	DOTFILES_NVIM_ORG_RESTORE_SCRIPT="${repo}/mk/restore-nvim-org.lua" \
	DOTFILES_NVIM_VERIFY_SCRIPT="${repo}/mk/verify-nvim-plugins.lua" \
	"$nvim_bin" --headless \
	"+lua require('lazy').restore({ wait = true, show = false })" \
	"+TSUpdateSync ${parsers}" \
	"+lua dofile(vim.env.DOTFILES_NVIM_PARSER_VERIFY_SCRIPT)" \
	"+lua dofile(vim.env.DOTFILES_NVIM_ORG_RESTORE_SCRIPT)" \
	"+lua dofile(vim.env.DOTFILES_NVIM_VERIFY_SCRIPT)" +qa || exit $?
cmp -s "$snapshot" "${lock_file}" || {
	diff -u "$snapshot" "${lock_file}" || true
	echo "Neovim restore changed the lock; update specs or run 'make nvim-update'"
	exit 1
}
