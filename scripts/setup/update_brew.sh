#!/bin/bash

core_packages=(
  tmux # terminal multiplexer
  zplug # zsh plugin management
  zsh # e.g. `git status | fpp` -> pick files -> `c` -> `git checkout master`bash replacement
)

editor_packages=(
  neovim
  vim # vim 4 life
)

qol_packages=(
  bat # better `less`
  diff-so-fancy # better `diff`
  exa # better `ls`
  fd # better `find`
  fortune # fortune cookie phrases - very important :p
  fpp # facebook path picker - pipe in txt, pick files, do thing
  fzf # fuzzy finder
  fzy # rust fuzzy finder
  highlight # syntax highlighter
  htop # better `top`
  ncdu # better `du`
  parallel # GNU parallel - better `xargs`
  prettyping # better `ping`
  ranger # cli file system browser - start with ^k
  ripgrep # rg - better cli search - used by fzf
  tldr # better `man`
  youtube-dl # download youtube
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

# temporary until universal-ctags gets a v1.0, then it will be a normal package
brew install --HEAD universal-ctags/universal-ctags/universal-ctags

