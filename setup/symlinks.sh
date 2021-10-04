#!/bin/bash

blacklist=(
  setup
  osx
  taskwarrior
)

dotfiles_dir=${dotfiles_dir:-$PWD}
cd $dotfiles_dir

for abs_dir in $dotfiles_dir/*/; do
  dir=$(basename $abs_dir)
  if [ "$(echo ${blacklist[@]} | grep -o $dir | wc -w)" -eq "0" ]; then
    echo "stowing $dir"
    stow -t ~ $dir
  fi
done

if [ ! -z "$1" ]; then
  echo "stowing $1"
  stow -t ~ $1
fi
