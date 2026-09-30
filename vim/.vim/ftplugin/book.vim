if exists("b:did_book_ftplugin")
   finish
endif
let b:did_book_ftplugin = 1

" DEFAULT TO MARKDOWN
runtime! ftplugin/markdown.vim

" DEFER SWITCHING TO vimwiki SYNTAX
augroup bookSyntax
  au! * <buffer>
  autocmd Syntax   <buffer> call SetBookSyntax()
augroup END
function! SetBookSyntax()
  set syntax=vimwiki
endfunction

" LOAD (80 columns by 100% height) DISTRACTION FREE READING
augroup bookGoyo
  autocmd! * <buffer>
  if !v:vim_did_enter
    autocmd VimEnter <buffer> ++once if exists(':Goyo') == 2 | Goyo 80x100% | endif
  else
    autocmd BufWinEnter <buffer> ++once if exists(':Goyo') == 2 | Goyo 80x100% | endif
  endif
augroup END

" PROSE SETTINGS
setlocal wrap " softwrap
setlocal linebreak " break around words
setlocal conceallevel=2 " hide concealable text
setlocal concealcursor=nc " don't expand until insert
