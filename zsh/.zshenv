# this file should be symlinked to ~/.zshenv
# ~/.zshenv is always sourced
# use ~/.zshrc for interactive-only

# source ~/.zshenv.local if present
[[ -f $HOME/.zshenv.local ]] && source $HOME/.zshenv.local

export SHELL=$(which zsh)


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
  "$HOME/bin"
  "$HOME/.local/bin"
  "$HOME/.local/share/mise/shims"
  '/usr/local/bin'
  '/usr/bin'
  '/bin'
  $path
)

# user-level npm packages
export NPM_GLOBALS="$HOME/.config/npm/globals"
export NPM_CONFIG_PREFIX="$NPM_GLOBALS"
path+=("$NPM_GLOBALS/bin")

# source haskell setup if present
if [[ -f $HOME/.ghcup/env ]]; then
  source $HOME/.ghcup/env
  path+="$HOME/.cabal/bin"
  path+="$HOME/.ghcup/bin"
fi

export PATH
