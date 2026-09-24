# Preserve any profile that predates the managed dotfile.
if [[ -f $HOME/.zprofile.local ]]; then
  source "$HOME/.zprofile.local"
fi

# macOS /etc/zprofile runs path_helper after .zshenv. Restore user tools first.
typeset -U path
path=(
  "$HOME/bin"
  "$HOME/.local/bin"
  "$HOME/.local/share/mise/shims"
  /opt/homebrew/bin
  $path
)
export PATH
