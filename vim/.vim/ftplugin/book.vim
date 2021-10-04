if exists("b:did_book_ftplugin")
   finish
endif
let b:did_book_ftplugin = 1

" DEFAULT TO MARKDOWN
runtime! ftplugin/markdown.vim

" DEFER SWITCHING TO vimwiki SYNTAX
augroup bookSyntax
  au!
  autocmd Syntax   <buffer> call SetBookSyntax()
augroup END
function! SetBookSyntax()
  set syntax=vimwiki
endfunction

" LOAD (80 columns by 100% height) DISTRACTION FREE READING
Goyo 80x100%

" PROSE SETTINGS
setlocal wrap " softwrap
setlocal linebreak " break around words
setlocal conceallevel=2 " hide concealable text
setlocal concealcursor=nc " don't expand until insert
