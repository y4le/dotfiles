#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path
set -eu

nvim_bin=$1
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

env -i HOME="$test_root" PATH="$PATH" \
  XDG_CONFIG_HOME="$test_root/.config" XDG_DATA_HOME="$test_root/.local/share" \
  XDG_STATE_HOME="$test_root/.local/state" XDG_CACHE_HOME="$test_root/.cache" \
  DOTFILES_REPO="$repo" DOTFILES_TEST_SCRIPT="$repo/mk/test-nvim-editing.lua" \
  "$nvim_bin" --headless -u NONE -i NONE \
  '+lua dofile(vim.env.DOTFILES_TEST_SCRIPT)' +qa
