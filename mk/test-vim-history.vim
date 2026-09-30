execute 'set runtimepath^=' . fnameescape($DOTFILES_REPO . '/vim/.vim')
let $VIMHOME = $DOTFILES_REPO . '/vim/.vim'
let $VIMSTATE = $DOTFILES_TEST_ROOT . '/defaults-state'
let original_viminfo = &viminfo
execute 'source ' . fnameescape($VIMHOME . '/config/settings.vim')
call assert_equal(substitute(original_viminfo, "'\\d\\+", "'1000", ''), &viminfo,
  \ 'recent file history depth changed unrelated Viminfo options')

" Persist enough actual file marks to exceed Vim's default 100-file limit.
call mkdir($DOTFILES_TEST_ROOT . '/visited', 'p')
for index in range(125)
  let path = $DOTFILES_TEST_ROOT . '/visited/' . index . '.txt'
  call writefile(['visited'], path)
  execute 'edit ' . fnameescape(path)
  normal! G
  bdelete
endfor
wviminfo!
rviminfo!
let persisted = filter(copy(v:oldfiles), 'stridx(v:val, $DOTFILES_TEST_ROOT . "/visited/") == 0')
call assert_equal(125, len(persisted), 'recent files were truncated to the old default limit')
if !empty(v:errors)
  call writefile(v:errors, $DOTFILES_TEST_ROOT . '/errors')
  cquit
endif
qa!
