#!/bin/bash

# get absolute location of dotfiles repo dir
export script_source="$0"
export current_dir="$PWD"
[ -n "${BASH_SOURCE[0]}" ] && export script_source=${BASH_SOURCE[0]}
export dotfiles_dir="$( cd "$(dirname "$script_source")" ; pwd -P )"

# sh $dotfiles_dir/setup/maybe_install_brew.sh
# sh $dotfiles_dir/setup/update_brew.sh
sh $dotfiles_dir/setup/symlinks.sh $@

