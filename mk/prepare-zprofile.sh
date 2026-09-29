#!/bin/sh

set -eu

mode=$1
home=$2
repo=$3
target=$home/.zprofile
local_profile=$home/.zprofile.local

if [ "$mode" = --is-managed ]; then
  [ -L "$target" ] || exit 1
  link=$(readlink "$target")
  case "$link" in
    /*) linked_path=$link ;;
    *) linked_path=$home/$link ;;
  esac
  linked_parent=$(CDPATH='' cd -- "$(dirname "$linked_path")" 2>/dev/null && pwd -P) || exit 1
  repo_root=$(CDPATH='' cd -- "$repo" && pwd -P)
  [ "$linked_parent/$(basename "$linked_path")" = "$repo_root/osx/.zprofile" ]
  exit $?
fi

if [ "$mode" = --restore ]; then
  if [ ! -e "$target" ] && [ ! -L "$target" ] && \
    { [ -e "$local_profile" ] || [ -L "$local_profile" ]; }; then
    if [ -d "$local_profile" ] && [ ! -L "$local_profile" ]; then
      echo "cannot restore ~/.zprofile: ~/.zprofile.local is a directory" >&2
      exit 1
    fi
    mv "$local_profile" "$target"
    echo 'restored original ~/.zprofile from ~/.zprofile.local'
  fi
  exit 0
fi

if [ ! -e "$target" ] && [ ! -L "$target" ]; then
  [ "$mode" != --plan ] || printf 'LINK: .zprofile => %s/osx/.zprofile\n' "$repo"
  exit 0
fi

if [ -d "$target" ] && [ ! -L "$target" ]; then
  echo "cannot link ~/.zprofile: existing path is a directory" >&2
  exit 1
fi

if [ -L "$target" ]; then
  link=$(readlink "$target")
  case "$link" in
    /*) linked_path=$link ;;
    *) linked_path=$home/$link ;;
  esac
  linked_parent=$(cd "$(dirname "$linked_path")" 2>/dev/null && pwd -P) || linked_parent=
  repo_root=$(cd "$repo" && pwd -P)
  if [ "$linked_parent/$(basename "$linked_path")" = "$repo_root/osx/.zprofile" ]; then
    exit 0
  fi
fi

if [ -e "$local_profile" ] || [ -L "$local_profile" ]; then
  echo "cannot preserve existing ~/.zprofile: ~/.zprofile.local already exists" >&2
  exit 1
fi

case "$mode" in
  --plan)
    echo 'would preserve existing ~/.zprofile as ~/.zprofile.local'
    printf 'LINK: .zprofile => %s/osx/.zprofile\n' "$repo"
    ;;
  --apply)
    mv "$target" "$local_profile"
    echo 'preserved existing ~/.zprofile as ~/.zprofile.local'
    ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
