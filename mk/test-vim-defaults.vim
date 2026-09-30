execute 'set runtimepath^=' . fnameescape($DOTFILES_REPO . '/vim/.vim')
let $VIMHOME = $DOTFILES_REPO . '/vim/.vim'
let $VIMSTATE = $DOTFILES_TEST_ROOT . '/defaults-state'
execute 'source ' . fnameescape($VIMHOME . '/config/settings.vim')
execute 'source ' . fnameescape($VIMHOME . '/config/maps.vim')
call assert_equal(0, &regexpengine, 'automatic regex selection was overridden')
set wrap columns=40
call setline(1, [repeat('x', 160), 'two', 'three', 'four', 'five'])
normal! gg0
normal j
call assert_equal(1, line('.'), 'uncounted j skipped wrapped text')
call assert_true(virtcol('.') > 40, 'uncounted j did not move a screen line')
normal k
call assert_equal(1, line('.'))
call assert_equal(1, col('.'), 'uncounted k did not return a screen line')
normal! gg0
normal 3j
call assert_equal(4, line('.'), 'counted j used screen lines')
normal 3k
call assert_equal(1, line('.'), 'counted k used screen lines')

if !empty(v:errors)
  call writefile(v:errors, $DOTFILES_TEST_ROOT . '/errors')
  cquit
endif
qa!
