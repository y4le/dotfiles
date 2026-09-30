if exists("b:did_book_ftplugin")
   finish
endif
let b:did_book_ftplugin = 1

" DEFAULT TO MARKDOWN
runtime! ftplugin/markdown.vim

" PROSE SETTINGS
setlocal wrap " softwrap
setlocal linebreak " break around words
setlocal conceallevel=2 " hide concealable text
setlocal concealcursor=nc " don't expand until insert
