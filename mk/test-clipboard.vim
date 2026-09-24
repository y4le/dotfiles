let mapleader = ' '
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/cpst.vim')
call setline(1, 'KEEP THIS')
normal gg
execute "normal \<Space>pp"
call writefile([getline(1)], $DOTFILES_TEST_OUTPUT)
qa!
