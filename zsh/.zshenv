# this file should be symlinked to ~/.zshenv
# ~/.zshenv is always sourced
# use ~/.zshrc for interactive-only

# source ~/.zshenv.local if present
[[ -f $HOME/.zshenv.local ]] && source $HOME/.zshenv.local

export SHELL=$(which zsh)

export BROWSER='chromium-browser'

export EDITOR=vim # vim 4 life
export VISUAL=vim
export GIT_EDITOR=$EDITOR

export LESS='-imJMWR'
export PAGER="less $LESS"
type vimpager &>/dev/null && export PAGER='vimpager'
export MANPAGER=$PAGER
export GIT_PAGER=$PAGER

# no duplicates in path
typeset -U path

 #set up $PATH
path=(
  "$HOME/homebrew/bin"
  "$HOME/homebrew/sbin"
  "$HOME/bin"
  '/usr/local/bin'
  '/usr/bin'
  '/bin'
  $path
)

export PATH
