# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.  # Look in ~/.oh-my-zsh/themes/
ZSH_THEME="yale"

COMPLETION_WAITING_DOTS="true"
export HISTSIZE=32768;
export HISTFILESIZE=$HISTSIZE;
export HISTCONTROL=ignoredups;
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help";
export EDITOR='vim'
bindkey -v

source $ZSH/oh-my-zsh.sh
source /opt/boxen/env.sh

plugins=(git z brew catimg git-extras nyan)

export PATH="/opt/boxen/bin:$PATH"
export PATH="/opt/boxen/nodenv/bin:$PATH"
export PATH="/opt/boxen/homebrew/share/python:$PATH"
export PATH="/opt/boxen/homebrew/sbin:$PATH"
export PATH="/opt/X11/bin:$PATH"
export PATH="/Users/ythomas/src/arcanist/arcanist/bin:$PATH"
export PATH="node_modules/.bin:$PATH"
export PATH="/opt/boxen/nodenv/shims:$PATH"
export PATH="/opt/boxen/homebrew/bin/:$PATH"
export PATH="/opt/boxen/homebrew/bin:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="/usr/sbin:$PATH"
export PATH="/bin:$PATH"
export PATH="/sbin:$PATH"
export PATH="~/bin:$PATH"
export PATH="/opt/local/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/bin/:$PATH"

alias ss="workon rdio && ./manage.py superserver"
alias rdio="cd ~/src/rdio/rdio/"
alias flux="cd ~/src/rdio/rdio/web/client/flux"
alias re-ss="cd ~/src/rdio/rdio/web/client && make reset && ss"

d() {
  if test "$#" = 0; then
    (
    git diff --color
    git ls-files --others --exclude-standard |
    while read -r i; do git diff --color -- /dev/null "$i"; done
    ) | `git config --get core.pager`
  else
    git diff "$@"
  fi
}

subd() {
  git diff master --name-only | xargs subl -a
}

ip() {
  if test "$1" = "copy"; then (
    ifconfig en0 inet | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | pbcopy
  ) fi
  ifconfig en0 inet | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

