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
  fd # better `find`
  jq # json cli
  bat # better `cat`
  htop # better `top`
  ncdu # better `du`
  tldr # better `man`
  prettyping # better `ping`
  diff-so-fancy # better `diff`
)

packages=(${core_packages[@]} ${editor_packages[@]} ${qol_packages[@]})

brew install ${packages[@]}
brew upgrade ${packages[@]}

