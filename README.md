# Dotfiles

Configuration files for development environment, managed with GNU stow.

### Setup
First clone the repo to any directory in $HOME (should be top-level).

#### Base
* (git, stow), bash, tmux, vim, neovim, upower

``` bash
./setup.sh
```

#### Graphical
* xmonad, x11-server-utils, xinit, xcape, xclip, xdg-utils
* xautolock, physlock, pm-utils
* urxvt, rofi, icecat/firefox, vimperator

``` bash
$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh
./setup_graphical.sh
```

#### Other
* zlib1g-dev, libssl-dev, build-essential, cmake
* rustup, exa, rg
