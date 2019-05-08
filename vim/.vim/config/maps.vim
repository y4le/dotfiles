let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

nnoremap ; :|" easier command mode access

nnoremap <C-j> <C-W>j|" move
nnoremap <C-k> <C-W>k|" panes
nnoremap <C-h> <C-W>h|" with
nnoremap <C-l> <C-W>l|" ctrl+h/j/k/l

nnoremap j gj|" j moves down visible instead of file lines
nnoremap k gk|" k moves up visible instead of file lines

nnoremap <leader>bx :bd<cr>|" close buffer and close window/split
nnoremap <leader>bX :bp\|bd #<cr>|" close buffer and preserve window/split
nnoremap <leader>bN :enew<cr>|" new buffer

" fzf so good! use these
nnoremap <leader>j :Buffers<cr>|" pick open buffers by id/filename
nnoremap <leader>bb :Buffers<cr>|" pick open buffers by id/filename
nnoremap <leader>bl :Lines<cr>|" find line in any open buffer
nnoremap <leader>n :Files<cr>|" pick from all files in vim's root dir by filename
nnoremap <leader>N :GFiles<cr>|" pick from all files in git project by filename
nnoremap <leader>R :Rg<cr>|" fulltext find in all files in the base dir
nnoremap <leader>g :Tags<cr>|" tags in project
nnoremap <leader>G :BTags<cr>|" tags in current buffer
" nnoremap <leader>F :call NerdTreeFZF()<cr>|"
" TODO leader f -> :FZF on cwd

" toggles
nnoremap <leader>tt :TagbarToggle<CR>|"   toggle tagbar ctags browser sidebar
nnoremap <leader>tn :NERDTreeToggle<CR>|" toggle NERDTree directory sidebar
nnoremap <leader>tN :NERDTreeFind<CR>|" locate current file in NERDTree
nnoremap <leader>tu :UndotreeToggle<CR>|" toggle UndoTree undo history sidebar
nnoremap <leader>tr :set relativenumber!<CR>|" toggle relative line ##s

" quickfix
nnoremap <leader>qq :call asyncrun#quickfix_toggle(8)<CR>|" toggle quickfix pane
nnoremap <leader>qn :cn<CR>|" quickfix next
nnoremap <leader>qp :cp<CR>|" quickfix prev

" source locally specific vimrc if present
call SourceIfExists("~/.vim/config/maps.local.vim")
