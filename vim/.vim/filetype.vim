if exists("did_load_filetypes")
  finish
endif

augroup filetypedetect
  autocmd!
  autocmd BufRead,BufNewFile *.tmux.conf setfiletype tmux
  autocmd BufRead,BufNewFile *.wiki if exists("g:loaded_vimwiki") | setfiletype vimwiki | else | setfiletype markdown | endif
  autocmd BufRead,BufNewFile *.book setfiletype book | setlocal syntax=vimwiki
augroup END
