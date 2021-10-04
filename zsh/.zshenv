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
  '/bin'
  '/usr/bin'
  '/usr/local/bin'
  "$HOME/bin"
  $path
)

# set up (n)ode (p)ackage (m)anager for js packages
if type npm &>/dev/null; then
  export NPM_PREFIX="$HOME/.config/npm"
  export NPM_GLOBALS="$NPM_PREFIX/globals"
  mkdir -p $NPM_GLOBALS
  npm config --global set prefix $NPM_GLOBALS
  path+="$NPM_GLOBALS/bin"
fi

# source haskell setup if present
if [[ -f $HOME/.ghcup/env ]]; then
  source $HOME/.ghcup/env
  path+="$HOME/.cabal/bin"
  path+="$HOME/.ghcup/bin"
fi

export PATH
