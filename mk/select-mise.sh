#!/bin/sh

# Project a selection into HOME without changing the canonical tool catalog.
set -eu
mode=$1
repo=$(CDPATH='' cd -P -- "$2" && pwd -P)
target_home=$3
catalog=$4
selected=${5:-}
target=$target_home/.config/mise/conf.d/dotfiles.toml
marker="# dotfiles mise selection: $repo"
case $mode in --check|--plan|--apply|--clean) ;; *) echo "unknown mise selection mode: $mode" >&2; exit 2 ;; esac

fail() { echo "mise selection: $*" >&2; exit 1; }
check_parents() {
  for parent in "$target_home/.config" "$target_home/.config/mise" "$target_home/.config/mise/conf.d"; do
    if [ -L "$parent" ]; then
      # Stow unfolds this owned legacy directory before --apply writes anything.
      if [ "$mode" != --apply ] && [ "$mode" != --clean ] &&
        [ "$parent" = "$target_home/.config/mise" ] &&
        [ "$(CDPATH='' cd -P -- "$parent" && pwd -P)" = "$repo/mise/.config/mise" ]; then
        continue
      fi
      echo "mise selection: symlink parent must be made a real directory: $parent" >&2
      return 1
    fi
    if [ -e "$parent" ] && [ ! -d "$parent" ]; then
      echo "mise selection: parent is not a directory: $parent" >&2
      return 1
    fi
  done
}
is_owned() {
  [ ! -L "$target" ] && [ -f "$target" ] || return 1
  first_line=
  IFS= read -r first_line < "$target" || true
  [ "$first_line" = "$marker" ]
}
check_target() {
  if [ -e "$target" ] || [ -L "$target" ]; then
    is_owned || fail "refusing foreign file or symlink: $target; move it aside after review"
  fi
}

if [ "$mode" = --clean ]; then
  if check_parents && is_owned; then
    rm "$target"
    echo "removed owned mise selection: $target"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    echo "preserving unmanaged mise selection: $target"
  fi
  exit 0
fi
check_parents || exit 1
check_target
if [ "$mode" = --check ]; then
  awk -v action=entries -v selected="$selected" -f "$repo/mk/catalog.awk" "$catalog" >/dev/null
  exit 0
fi
umask 077
if [ "$mode" = --apply ]; then
  mkdir -p "${target%/*}"
  # No .toml suffix: mise must never load the in-progress fragment.
  tmp=$(mktemp "${target%/*}/.dotfiles.XXXXXX")
else
  tmp=$(mktemp)
fi
trap 'rm -f "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
{
  printf '%s\n' "$marker"
  echo '# Replaced by make link. Put overrides in ~/.config/mise/config.local.toml.'
  echo '[tools]'
  awk -v action=entries -v selected="$selected" -f "$repo/mk/catalog.awk" "$catalog"
} > "$tmp"
if [ -f "$target" ] && cmp -s "$target" "$tmp"; then
  echo "mise selection unchanged: $target"
  exit 0
fi
if [ "$mode" = --plan ]; then
  current=/dev/null
  [ ! -f "$target" ] || current=$target
  diff -u -L "$target (current)" -L "$target (selected)" "$current" "$tmp" || {
    status=$?
    [ "$status" -eq 1 ] || exit "$status"
  }
else
  check_target
  mv "$tmp" "$target"
  echo "wrote owned mise selection: $target"
fi
