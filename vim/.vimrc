let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

" each of these will try to source a .local version at the end
" e.g. ~/.vim/config/functions.local.vim
source ~/.vim/config/functions.vim
source ~/.vim/config/plugins.vim
source ~/.vim/config/settings.vim
source ~/.vim/config/maps.vim
