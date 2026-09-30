# Preserve any profile that predates the managed dotfile.
if [[ -f $HOME/.zprofile.local ]]; then
  source "$HOME/.zprofile.local"
fi

# Undo path_helper's reorder while keeping any new system entries.
if (( ${+_dotfiles_login_path} )); then
  typeset -U path
  typeset -a _dotfiles_local_prefix
  _dotfiles_local_prefix=()
  for _dotfiles_dir in $path; do
    case $_dotfiles_dir in /usr/local/bin|/usr/bin|/bin) break ;; esac
    (( $_dotfiles_login_path[(Ie)$_dotfiles_dir] )) || _dotfiles_local_prefix+=("$_dotfiles_dir")
  done
  _dotfiles_system=1
  for _dotfiles_dir in $_dotfiles_login_path; do
    case $_dotfiles_dir in /usr/local/bin|/usr/bin|/bin) break ;; esac
    (( _dotfiles_system++ ))
  done
  if (( _dotfiles_system == 1 )); then
    path=($_dotfiles_local_prefix $_dotfiles_login_path $path)
  else
    path=(${_dotfiles_login_path[1,_dotfiles_system-1]} $_dotfiles_local_prefix
      ${_dotfiles_login_path[_dotfiles_system,-1]} $path)
  fi
  unset _dotfiles_local_prefix _dotfiles_dir _dotfiles_system
  unset _dotfiles_login_path
fi

export PATH
