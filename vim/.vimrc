if has('win32') || has ('win64')
  let $VIMHOME = $VIM . "/vimfiles"
  let $VIMSTATE = $VIMHOME
else
  let $VIMHOME = $HOME . "/.vim"
  let $VIMSTATE = (exists('$XDG_STATE_HOME') && $XDG_STATE_HOME =~# '^/'
    \ ? $XDG_STATE_HOME : $HOME . "/.local/state") . "/vim"
endif

let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

" each of these will try to source a .local version at the end
" e.g. $VIMHOME/config/plugins.local.vim
source $VIMHOME/config/plugins.vim
source $VIMHOME/config/settings.vim
source $VIMHOME/config/maps.vim

call util#SourceIfExists("~/.vimrc.local")
