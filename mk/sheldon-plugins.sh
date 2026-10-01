#!/bin/sh

set -eu

sheldon_bin=$1
config_file=$2
data_dir=$3
target_home=$4

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
trap 'rm -f "$tmp"' EXIT
trap 'rm -f "$tmp"; exit 1' HUP INT TERM
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
mv "$tmp" "$cache" || exit $?
echo "wrote $cache"
