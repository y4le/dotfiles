#!/bin/sh

set -eu

[ "$#" -eq 2 ] || {
  echo "usage: $0 MISE_BIN MISE_CONFIG_FILE" >&2
  exit 1
}

mise_bin=$1
mise_config_file=$2

repo=$(CDPATH='' cd -P -- "${0%/*}/.." && pwd -P)

if [ -x "$mise_bin" ]; then
  nvim_bin=$(MISE_CEILING_PATHS="$repo" MISE_GLOBAL_CONFIG_FILE="$mise_config_file" \
    "$mise_bin" which nvim 2>/dev/null || true)
  if [ -n "$nvim_bin" ] && [ -x "$nvim_bin" ]; then
    printf '%s\n' "$nvim_bin"
    exit 0
  fi
fi

nvim_bin=$(command -v nvim 2>/dev/null || true)
if [ -n "$nvim_bin" ] && [ -x "$nvim_bin" ]; then
  printf '%s\n' "$nvim_bin"
  exit 0
fi

echo "Neovim not found. Install it with 'make tools'." >&2
exit 1
