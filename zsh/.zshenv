# this file should be symlinked to ~/.zshenv
# ~/.zshenv is always sourced
# use ~/.zshrc for interactive-only

# source machine-local environment before setting portable defaults
if [[ -f $HOME/.config/zsh/hooks/env.zsh ]]; then
  source $HOME/.config/zsh/hooks/env.zsh
elif [[ -f $HOME/.zshenv.local ]]; then
  source $HOME/.zshenv.local
fi

export SHELL=${commands[zsh]:-${SHELL:-/bin/zsh}}


export EDITOR=vim # vim 4 life
export VISUAL=vim
export GIT_EDITOR=$EDITOR

export LESS='-imJMWR'
export PAGER="less $LESS"

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
export NPM_GLOBALS="${XDG_DATA_HOME:-$HOME/.local/share}/npm"
export NPM_CONFIG_PREFIX="$NPM_GLOBALS"
path+=("$NPM_GLOBALS/bin")

# source haskell setup if present
if [[ -f $HOME/.ghcup/env ]]; then
  source $HOME/.ghcup/env
  path+="$HOME/.cabal/bin"
  path+="$HOME/.ghcup/bin"
fi

# add packages controlled by brew to PATH if present
if [[ -d /opt/homebrew/bin ]]; then
  path=("$HOME/bin" "$HOME/.local/bin" "$HOME/.local/share/mise/shims" /opt/homebrew/bin $path)
fi

# Keep cargo-installed utilities available after mise's pinned Rust shims.
if [[ -d $HOME/.cargo/bin ]]; then
  path+=("$HOME/.cargo/bin")
fi

export PATH
