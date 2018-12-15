#!/bin/bash

core_packages=(
  asdf # multi version manager, replaces rvm/nvm
  tmux # terminal multiplexer
  zplug # zsh plugin management
  zsh # e.g. `git status | fpp` -> pick files -> `c` -> `git checkout master`bash replacement
)

vcs_packages=(
  git # og distributed version control
  mercurial # `hg`, the new hotness
)

editor_packages=(
  neovim
  vim # vim 4 life
)

other_packages=(
  bat # better `less`
  diff-so-fancy # better `diff`
  exa # better `ls`
  fd # better `find`
  fortune # fortune cookie phrases - very important :p
  fpp # facebook path picker - pipe in txt, pick files, do thing
  fzf # fuzzy finder
  fzy # rust fuzzy finder
  gpg # GNU privacy guard, public/private key encryption
  highlight # syntax highlighter
  htop # better `top`
  jq # json utils
  ncdu # better `du`
  parallel # GNU parallel - better `xargs`
  poppler # pdf rendering library
  prettyping # better `ping`
  pv # pipeviewer - view data moving through bash pipe
  ranger # cli file system browser - start with ^k
  ripgrep # rg - better cli search - used by fzf
  tldr # better `man`
  tree # display directories as trees
  watch # do something periodically and display results
  watchman # watch files and do something on change
  wget # get files from the internet
  youtube-dl # download youtube
)

language_packages=(
  # go # strong static typed, concurrent, compiled, systems language
  go

  # javascript # weak dynamic typed, high level, interpreted language
  node # js runtime
  flow # static type checking for js
  yarn # js dependency management

  # lisp # strong dynamic typed, high level, interactive, interpreted/compiled language
  sbcl # common lisp interpreter

  # ocaml # strong static typed, functional flavored, interpreted/compiled language
  ocaml
  opam # ocaml package manager

  # octave # high level, array oriented, interpreted language for math
  octave

  # python # strong dynamic typed, high level, interpreted language
  python

  # R # dynamic typed, high level, array oriented, interpreted language for statistics
  r

  # ruby # strong dynamic typed, high level, interpreted, scripting language
  ruby

  # rust # strong static typed, safe, compiled, systems language
  rust
)

lib_packages=(
  autoconf # generate configure scripts
  automake # generate gnu makefiles
  cmake # cross platform make
  coreutils # gnu file/shell/text utils
  ffmpeg # play/record/convert/stream audio and video
  imagemagick # image manipulation
  libtool # gnu generic library tool
  libxslt # c xslt (xml) library
  libyaml # yaml (like json, but better) library
  openblas # optimized linear algebra library
  openssl # ssl crypto library
  readline # libary for command line editing
  unixodbc # standardized API for data sources e.g. mysql
)

packages=(${lib_packages[@]} ${core_packages[@]} ${vcs_packages[@]} ${language_packages[@]} ${editor_packages[@]} ${other_packages[@]})

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

