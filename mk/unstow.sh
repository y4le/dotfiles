#!/bin/sh

set -eu

mode=$1
repo=$2
home=$3
stow=$4
shift 4

repo_root=$(CDPATH='' cd -- "$repo" && pwd -P) || exit 1
atuin_dir=$(CDPATH='' cd -- "$home/.config/atuin" 2>/dev/null && pwd -P) || atuin_dir=
packages=
for package do
  # An Atuin hook in an existing shell can recreate this file after the
  # managed link is removed. It is now user-owned, so leave it alone while
  # unstowing the other packages.
  if [ "$package" = atuin ] &&
    [ -f "$home/.config/atuin/config.toml" ] &&
    [ ! -L "$home/.config/atuin/config.toml" ] &&
    [ "$atuin_dir/config.toml" != "$repo_root/atuin/.config/atuin/config.toml" ]; then
    extra=$(find "$repo_root/atuin" \( -type f -o -type l \) \
      ! -path "$repo_root/atuin/.config/atuin/config.toml" -print) || exit 1
    if [ -n "$extra" ]; then
      echo "cannot preserve Atuin config while the package has other files: $extra" >&2
      exit 1
    fi
    echo "preserving unmanaged ~/.config/atuin/config.toml; move it aside before selecting Atuin"
    continue
  fi
  packages="$packages $package"
done

[ -n "$packages" ] || exit 0
# Package names come from the validated profile data or fixed Make variables.
# shellcheck disable=SC2086
set -- $packages
case " $packages " in
  *' osx '*)
    if ! sh "$(dirname "$0")/prepare-zprofile.sh" --is-managed "$home" "$repo"; then
      set -- --ignore='^\.zprofile$' "$@"
    fi
    ;;
esac

case "$mode" in
  # Keep these Stow options aligned with STOW_FLAGS in mk/config.mk.
  --plan) "$stow" -n -v -D --no-folding -d "$repo" -t "$home" "$@" ;;
  --apply) "$stow" -D --no-folding -d "$repo" -t "$home" "$@" ;;
  *) echo "unknown unstow mode: $mode" >&2; exit 2 ;;
esac
