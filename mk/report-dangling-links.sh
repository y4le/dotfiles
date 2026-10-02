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
shift 2
# Enumerate source package roots, never HOME itself. For shared XDG containers,
# inspect only the application's destination, not unrelated config or data.
# Legacy roots remain explicit so retired links can still be reported.
roots=$(
  for package do
    for source in "$repo/$package"/.[!.]* "$repo/$package"/..?* "$repo/$package"/*; do
      [ -e "$source" ] || [ -L "$source" ] || continue
      relative=${source#"$repo/$package/"}
      case $relative in
        .config|.local)
          for child in "$source"/*; do
            [ -e "$child" ] || [ -L "$child" ] || continue
            if [ "$relative" = .local ] && [ "${child##*/}" != bin ]; then
              continue
            fi
            printf '%s/%s\n' "$relative" "${child##*/}"
          done
          ;;
        .stow-local-ignore|.gitignore) continue ;;
        *) printf '%s\n' "$relative" ;;
      esac
    done
  done
  printf '%s\n' .funcs bin .ideavimrc .tmux.conf .gitconfig .pre_profile .post_profile .zshenv.local
)
printf '%s\n' "$roots" | LC_ALL=C sort -u | while IFS= read -r relative; do
  [ -n "$relative" ] || continue
  destination=$home/$relative
  [ -e "$destination" ] || [ -L "$destination" ] || continue
  # Reporting is best-effort: unreadable managed destinations must not block
  # Stow. Never follow directory symlinks into unrelated trees.
  find "$destination" -type l -exec sh "$0" --inspect "$repo" "$home" {} + || :
done
