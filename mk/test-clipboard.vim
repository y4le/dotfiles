let mapleader = ' '
set shell=/bin/sh
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/cpst.vim')
call setline(1, 'KEEP THIS')
normal gg
call feedkeys("\<Space>pp", 'xt')
call writefile([getline(1), getreg('"')], $DOTFILES_TEST_OUTPUT)
qa!
