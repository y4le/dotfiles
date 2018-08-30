#!/bin/bash

# get absolute location of dotfiles repo dir
script_source="$0"
current_dir="${1-$PWD}"
[ -n "${BASH_SOURCE[0]}" ] && script_source=${BASH_SOURCE[0]}
repo_dir="$( cd "$(dirname "$script_source")" ; pwd -P )"

sh $repo_dir/scripts/setup/maybe_install_brew.sh
sh $repo_dir/scripts/setup/update_brew.sh
sh $repo_dir/scripts/setup/symlinks.sh

