#!/bin/sh

set -eu

[ "$#" -eq 3 ] || {
  echo "usage: $0 TOOL MISE_BIN MISE_CONFIG_FILE" >&2
  exit 1
}

tool=$1
mise_bin=$2
mise_config_file=$3

repo=$(CDPATH='' cd -P -- "${0%/*}/.." && pwd -P)

if [ -x "$mise_bin" ]; then
  tool_bin=$(MISE_CEILING_PATHS="$repo" MISE_GLOBAL_CONFIG_FILE="$mise_config_file" \
    "$mise_bin" which "$tool" 2>/dev/null || true)
  if [ -n "$tool_bin" ] && [ -x "$tool_bin" ]; then
    printf '%s\n' "$tool_bin"
    exit 0
  fi
fi

tool_bin=$(command -v "$tool" 2>/dev/null || true)
if [ -n "$tool_bin" ] && [ -x "$tool_bin" ]; then
  printf '%s\n' "$tool_bin"
  exit 0
fi

case $tool in nvim) label=Neovim ;; *) label=$tool ;; esac
echo "$label not found. Install it with 'make tools'." >&2
exit 1
