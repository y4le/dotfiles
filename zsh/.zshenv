# this file should be symlinked to ~/.zshenv
# ~/.zshenv is always sourced
# use ~/.zshrc for interactive-only

# Keep the host's global zshrc from initializing completion before our config.
skip_global_compinit=1

# source machine-local environment before setting portable defaults
if [[ -f $HOME/.config/zsh/hooks/env.zsh ]]; then
  source $HOME/.config/zsh/hooks/env.zsh
elif [[ -f $HOME/.zshenv.local ]]; then
  source $HOME/.zshenv.local
fi

export SHELL=${commands[zsh]:-${SHELL:-/bin/zsh}}


export LESS='-imJMWR'
export PAGER="less $LESS"

# no duplicates in path
typeset -U path

# Add missing defaults without moving entries inherited from the parent shell.
_dotfiles_shims="${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}"
typeset -a _dotfiles_defaults
_dotfiles_defaults=("$HOME/bin" "$HOME/.local/bin" "$_dotfiles_shims")
[[ -d /opt/homebrew/bin ]] && _dotfiles_defaults+=(/opt/homebrew/bin)
_dotfiles_defaults+=(/usr/local/bin /usr/bin /bin)
# Insert each missing default before its next neighbor, leaving custom prefixes
# and already-present entries in place. Append when no neighbor exists.
_dotfiles_next=0
for (( _dotfiles_i=${#_dotfiles_defaults}; _dotfiles_i >= 1; _dotfiles_i-- )); do
  _dotfiles_dir=$_dotfiles_defaults[_dotfiles_i]
  if (( ! $path[(Ie)$_dotfiles_dir] )); then
    if (( _dotfiles_next == 0 )); then
      path+=("$_dotfiles_dir")
    elif (( _dotfiles_next == 1 )); then
      path=("$_dotfiles_dir" $path)
    else
      path=(${path[1,_dotfiles_next-1]} "$_dotfiles_dir" ${path[_dotfiles_next,-1]})
    fi
  fi
  _dotfiles_next=$path[(Ie)$_dotfiles_dir]
done
unset _dotfiles_defaults _dotfiles_dir _dotfiles_next _dotfiles_i _dotfiles_shims

# user-level npm packages
export NPM_GLOBALS="${XDG_DATA_HOME:-$HOME/.local/share}/npm"
export NPM_CONFIG_PREFIX="$NPM_GLOBALS"
path+=("$NPM_GLOBALS/bin")

# Keep cargo-installed utilities available after mise's pinned Rust shims.
if [[ -d $HOME/.cargo/bin ]]; then
  path+=("$HOME/.cargo/bin")
fi

export PATH

# macOS path_helper runs between .zshenv and .zprofile in login shells.
if [[ -o login && $OSTYPE == darwin* ]]; then
  typeset -ga _dotfiles_login_path=($path)
fi

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi
export VISUAL=$EDITOR
