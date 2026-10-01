#!/bin/sh

set -eu

repo=$1
mise_bin=$2
mise_config=$3
lock_file=$4
parsers=$5

nvim_bin="$(sh mk/find-nvim.sh "${mise_bin}" "${mise_config}")" || exit $?
DOTFILES_NVIM_BOOTSTRAP=1 DOTFILES_NVIM_PARSERS="${parsers}" \
	DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="${repo}/mk/verify-nvim-parsers.lua" \
	DOTFILES_NVIM_ORG_RESTORE_SCRIPT="${repo}/mk/restore-nvim-org.lua" \
	"$nvim_bin" --headless "+Lazy! sync" \
	"+TSUpdateSync ${parsers}" \
	"+lua dofile(vim.env.DOTFILES_NVIM_PARSER_VERIFY_SCRIPT)" \
	"+lua dofile(vim.env.DOTFILES_NVIM_ORG_RESTORE_SCRIPT)" +qa || exit $?
git diff --stat -- "${lock_file}"
