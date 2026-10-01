#!/bin/sh

set -eu

dir=$1
url=$2
commit=$3
lock_file=$4

if ! command -v git >/dev/null 2>&1; then
	echo "git not found. Install it with your system package manager."
	exit 1
fi
if [ -z "${commit}" ]; then
	echo "lazy.nvim pin missing from ${lock_file}"
	exit 1
fi
mkdir -p "$(dirname "$dir")"
if [ -e "$dir" ] && [ ! -d "$dir/.git" ]; then
	echo "$dir exists but is not a git checkout"
	exit 1
fi
if [ ! -d "$dir/.git" ]; then
	tmp="$dir.tmp.$$"
	trap 'rm -rf "$tmp"' EXIT
	trap 'rm -rf "$tmp"; exit 1' HUP INT TERM
	git clone --no-checkout "${url}" "$tmp" </dev/null || exit $?
	git -c advice.detachedHead=false -C "$tmp" checkout -q --detach "${commit}" </dev/null || exit $?
	mv "$tmp" "$dir" || exit $?
	trap - EXIT HUP INT TERM
elif ! git -C "$dir" cat-file -e "${commit}^{commit}" </dev/null 2>/dev/null; then
	git -C "$dir" fetch "${url}" "${commit}" </dev/null || exit $?
fi
git -c advice.detachedHead=false -C "$dir" checkout -q --detach "${commit}" </dev/null || exit $?
actual="$(git -C "$dir" rev-parse HEAD)" || exit 1
if [ "$actual" != "${commit}" ]; then
	echo "lazy.nvim checkout mismatch: expected ${commit}, got $actual"
	exit 1
fi
