#!/bin/bash

core_packages=(
  tmux # terminal multiplexer
  zplug # zsh plugin management
)

editor_packages=(
  neovim
  vim # vim 4 life
)

other_packages=(
  bat # better `less`
  fzf # fuzzy finder
  ranger # cli file system browser - start with ^k
  ripgrep # rg - better cli search - used by fzf
  tldr # better `man`
)

packages=(${core_packages[@]} ${editor_packages[@]} ${other_packages[@]})

echo 'About to install and upgrade these packages:'
echo ${packages[@]}
read -p "Continue? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then # if reply is not y/Y
  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

brew install ${packages[@]}
brew upgrade ${packages[@]}

