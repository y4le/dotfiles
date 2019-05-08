#!/bin/bash

# get absolute location of dotfiles repo dir
script_source="$0"
current_dir="${1-$PWD}"
[ -n "${BASH_SOURCE[0]}" ] && script_source=${BASH_SOURCE[0]}
dotfiles_dir="$( cd "$(dirname "$script_source")" ; pwd -P )"

# sh $dotfiles_dir/setup/maybe_install_brew.sh
# sh $dotfiles_dir/setup/update_brew.sh
sh $dotfiles_dir/setup/symlinks.sh

