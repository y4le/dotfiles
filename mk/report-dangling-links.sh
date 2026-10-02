#!/bin/sh
set -eu

if [ "${1:-}" = --inspect ]; then
  repo=$2
  home=$3
  shift 3
  for path do
    [ ! -e "$path" ] || continue
    link=$(readlink "$path")
    case $link in
      /*) candidate=$link ;;
      *) candidate=$(dirname "$path")/$link ;;
    esac
    candidate=$(awk -v path="$candidate" 'BEGIN {
      n = split(path, parts, "/"); depth = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] == ".") continue
        if (parts[i] == "..") { if (depth) depth--; continue }
        stack[++depth] = parts[i]
      }
      for (i = 1; i <= depth; i++) printf "/%s", stack[i]
      print ""
    }')
    # Resolve an existing ancestor, even when a whole package was deleted.
    parent=$candidate
    suffix=
    while [ ! -d "$parent" ]; do
      suffix=/$(basename "$parent")$suffix
      parent=$(dirname "$parent")
    done
    parent=$(CDPATH='' cd -- "$parent" && pwd -P)
    case $parent$suffix in
      "$repo"/*) printf 'DANGLING: %s => %s\n' "${path#"$home"/}" "$link" ;;
    esac
  done
  exit 0
fi

repo=$(CDPATH='' cd -- "$1" && pwd -P)
home=$(CDPATH='' cd -- "$2" && pwd -P)
# Scan dotfiles destinations and legacy helper directories, avoiding unrelated
# source checkouts and runtime data elsewhere in HOME. Never follow symlinks.
# Reporting is best-effort: unreadable destinations must not block Stow.
find "$home" \( -type d ! -path "$home" \
  ! -path "$home/.config" ! -path "$home/.config/*" \
  ! -path "$home/.vim" ! -path "$home/.vim/*" \
  ! -path "$home/.agents" ! -path "$home/.agents/*" \
  ! -path "$home/.funcs" ! -path "$home/.funcs/*" \
  ! -path "$home/.local" ! -path "$home/.local/bin" ! -path "$home/.local/bin/*" \
  ! -path "$home/bin" ! -path "$home/bin/*" \) -prune \
  -o -type l -exec sh "$0" --inspect "$repo" "$home" {} + || :
