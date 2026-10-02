#!/bin/sh
set -eu

brew_bin=$1
prefix=$("$brew_bin" --prefix) || exit 1
cellar=$("$brew_bin" --cellar) || exit 1
for destination in "$prefix/bin" "$cellar" "$prefix/var/homebrew/locks"; do
  case $destination in
    /*) ;;
    *) echo "Homebrew returned an invalid installation path: $destination" >&2; exit 1 ;;
  esac
  parent=$destination
  while [ ! -e "$parent" ]; do parent=${parent%/*}; [ -n "$parent" ] || parent=/; done
  if [ ! -d "$parent" ] || [ ! -w "$parent" ]; then
    cat >&2 <<EOF
Homebrew at $brew_bin is read-only or not writable by this user ($parent).
'make system-packages' cannot use this managed installation.
Keep the IT-managed Homebrew; do not change its ownership or install another.
Use IT-supplied prerequisites, or install Stow and ShellCheck in user space:
see "Managed Macs with read-only Homebrew" in docs/setup.md.
Then run 'make setup-user', which does not modify Homebrew.
EOF
    exit 1
  fi
done
