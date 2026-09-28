#!/bin/sh

set -eu

stow_bin=$(command -v stow 2>/dev/null || true)
if [ -n "$stow_bin" ]; then
  printf '%s\n' "$stow_bin"
  exit 0
fi

if [ "${1:-}" = macos ]; then
  case $0 in
    */*) script_dir=${0%/*} ;;
    *) script_dir=$(command -v "$0"); script_dir=${script_dir%/*} ;;
  esac
  brew_bin=$(sh "$script_dir/find-brew.sh" 2>/dev/null || true)
  if [ -n "$brew_bin" ]; then
    stow_bin=${brew_bin%/*}/stow
    if [ -x "$stow_bin" ]; then
      printf '%s\n' "$stow_bin"
    fi
  fi
fi
