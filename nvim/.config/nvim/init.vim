" Reuse the existing Vim config until the Neovim-specific setup exists.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
