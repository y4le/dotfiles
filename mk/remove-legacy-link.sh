#!/bin/sh

set -eu

target=$1
repo=$2
old_path=$3

[ -L "$target" ] || exit 0
link=$(readlink "$target") || exit 1
case "$link" in
  */"$old_path") root_ref=${link%/"$old_path"} ;;
  *) exit 0 ;;
esac

case "$root_ref" in
  /*) linked_root=$(cd "$root_ref" 2>/dev/null && pwd -P) || exit 0 ;;
  *) linked_root=$(cd "$(dirname "$target")/$root_ref" 2>/dev/null && pwd -P) || exit 0 ;;
esac
repo_root=$(cd "$repo" && pwd -P) || exit 1
[ "$linked_root" = "$repo_root" ] || exit 0

echo "removing legacy managed $target link"
rm "$target"
