execute 'set runtimepath^=' . fnameescape($DOTFILES_REPO . '/vim/.vim')
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/sessions.vim')

call assert_false(stridx(&iskeyword, ':') >= 0, 'abbreviations changed iskeyword')
call feedkeys(":to let g:built_in = 1\<CR>", 'xt')
call assert_equal(1, get(g:, 'built_in', 0), ':to no longer means :topleft')

call setline(1, 'ss')
call feedkeys("/ss\<CR>", 'xt')
call assert_equal('ss', @/, 'session abbreviation expanded in search')
call feedkeys(":let g:session_text = 'ss'\<CR>", 'xt')
call assert_equal('ss', get(g:, 'session_text', ''), 'session abbreviation expanded in argument')

if len(v:errors)
  for error in v:errors
    echomsg error
  endfor
  cquit
endif
qa!
