#!/bin/sh

set -eu

sheldon_bin=$1
config_file=$2
data_dir=$3
target_home=$4
mise_bin=$5
mise_config=$6
fzf_bin=$7

if [ ! -x "${sheldon_bin}" ]; then
	echo "sheldon not found at ${sheldon_bin}; run 'make tools' first"
	exit 1
fi
if [ ! -f "${config_file}" ]; then
	echo "sheldon config is not linked; run 'make link' first"
	exit 1
fi
cache="${XDG_CACHE_HOME:-${target_home}/.cache}/dotfiles/sheldon.zsh"
dir="$(dirname "$cache")"
tmp="$cache.tmp.$$"
trap 'rm -f "$tmp" "$tmp.fzf" "$tmp.combined"' EXIT
trap 'exit 1' HUP INT TERM
umask 077
mkdir -p "$dir"
SHELDON_CONFIG_FILE="${config_file}" SHELDON_DATA_DIR="${data_dir}" \
	"${sheldon_bin}" lock || exit $?
SHELDON_CONFIG_FILE="${config_file}" SHELDON_DATA_DIR="${data_dir}" \
	"${sheldon_bin}" source > "$tmp" || exit $?
if [ ! -s "$tmp" ]; then
	echo "sheldon produced an empty startup cache"
	exit 1
fi
sh mk/verify-sheldon-plugins.sh verify "${config_file}" \
	"${data_dir}" "$tmp" || exit $?
# Bundle at restore time so deferred startup does not run a mise shim or
# discover a different fzf binary. Publish the integration and plugin list
# together, preserving the previous cache on any generation failure.
if grep -Eq '^[[:space:]]*use[[:space:]]*=[[:space:]]*\[.*"fzf\.zsh"' "$config_file"; then
  if [ -z "$fzf_bin" ]; then
    fzf_bin=$(sh mk/find-fzf.sh "$mise_bin" "$mise_config") || exit $?
  fi
  if ! "$fzf_bin" --zsh > "$tmp.fzf"; then
    echo "could not generate fzf integration from $fzf_bin; run 'make tools' or pass FZF_BIN" >&2
    exit 1
  fi
  [ -s "$tmp.fzf" ] || { echo "fzf produced empty shell integration" >&2; exit 1; }
  zsh -n "$tmp.fzf"
  if grep -Fxq '__DOTFILES_FZF_ZSH__' "$tmp.fzf"; then
    echo "fzf integration conflicts with the cache delimiter" >&2
    exit 1
  fi
  {
    printf 'function _dotfiles_fzf_init() {\n'
    # Parse when deferred, after fzf disables aliases, as upstream intends.
    printf "  'builtin' 'source' /dev/stdin <<'__DOTFILES_FZF_ZSH__'\n"
    cat "$tmp.fzf"
    printf '\n__DOTFILES_FZF_ZSH__\n}\n'
    cat "$tmp"
  } > "$tmp.combined"
  zsh -n "$tmp.combined"
  mv "$tmp.combined" "$tmp"
fi
mv "$tmp" "$cache" || exit $?
echo "wrote $cache"
