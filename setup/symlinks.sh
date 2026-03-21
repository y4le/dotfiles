#!/usr/bin/env zsh

if (( $+commands[xstow] )); then
  stow_cmd=xstow
elif (( $+commands[stow] )); then
  stow_cmd=stow
else
  echo "Neither xstow nor stow is installed" >&2
  exit 1
fi

blacklist=(
  setup
  osx
  taskwarrior
)

dotfiles_dir=${dotfiles_dir:-$PWD}
cd "$dotfiles_dir" || exit 1

stow_dir() {
  local dir="$1"
  echo "stowing $dir"
  "$stow_cmd" -t ~ "$dir"
}

if [ -n "$1" ]; then
  stow_dir "$1"
  exit $?
fi

for abs_dir in "$dotfiles_dir"/*/; do
  dir=$(basename "$abs_dir")
  if (( ${blacklist[(Ie)$dir]} == 0 )); then
    stow_dir "$dir"
  fi
done
