#!/bin/sh

set -eu

if [ "${BREW_SEARCH_PATHS+x}" = x ]; then
  search_paths=$BREW_SEARCH_PATHS
else
  search_paths='/opt/homebrew/bin/brew /usr/local/bin/brew'
fi

probe() {
  candidate=$1
  [ -x "$candidate" ] || return 1
  "$candidate" --prefix >/dev/null 2>&1 || return 1
  printf '%s\n' "$candidate"
}

path_candidate=$(command -v brew 2>/dev/null || true)
if [ -n "$path_candidate" ] && probe "$path_candidate"; then
  exit 0
fi

for candidate in $search_paths; do
  [ "$candidate" = "$path_candidate" ] && continue
  if probe "$candidate"; then
    exit 0
  fi
done

cat >&2 <<EOF
Homebrew is required for 'make system-packages' on macOS but was not found.
This repository does not install Homebrew: its installer is unpinnable, needs
admin sudo, and can install the Command Line Tools.
Install it yourself (see "macOS prerequisites" in docs/setup.md), then rerun.
'make setup-user' needs no Homebrew, but it does need stow, git, and vim.
Searched: PATH${search_paths:+, $search_paths}
EOF
exit 1
