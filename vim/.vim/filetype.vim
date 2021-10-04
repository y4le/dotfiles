if exists("did_load_filetypes")
  finish
endif

augroup filetypedetect
  autocmd!
  autocmd BufRead,BufNewFile *.tmux.conf setfiletype tmux
  autocmd BufRead,BufNewFile *.wiki setfiletype vimwiki
  autocmd BufRead,BufNewFile *.book setfiletype book
augroup END
