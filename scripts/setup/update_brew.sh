#!/bin/bash

core_packages=(
  tmux    # terminal multiplexer
  zsh     # e.g. `git status | fpp` -> pick files -> `c` -> `git checkout master`bash replacement
  antigen # zsh plugin management
)

editor_packages=(
  vim # vim 4 life
  neovim
)

qol_packages=(
  fzf # fuzzy finder - uses ripgrep to search - used by vim plugin
  ripgrep # rg - better cli search - used by fzf
  ranger # cli file system browser - start with ^k
  fpp # facebook path picker - pipe in txt, pick files, do thing
  jq # json cli
  fd # better `find`
  bat # better `less`
  htop # better `top`
  ncdu # better `du`
  tldr # better `man`
  prettyping # better `ping`
  diff-so-fancy # better `diff`
)

packages=(${core_packages[@]} ${editor_packages[@]} ${qol_packages[@]})

echo 'About to install and upgrade these packages:'
echo ${packages[@]}
read -p "Continue? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then # if reply is not y/Y
  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

brew install ${packages[@]}
brew upgrade ${packages[@]}

