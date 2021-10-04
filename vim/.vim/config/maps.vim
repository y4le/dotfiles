let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

nnoremap <leader>; @:|" repeat last command mode command. e.g. :buffernext

" improve defaults
nnoremap j gj|" j moves down visible instead of file lines
nnoremap k gk|" k moves up visible instead of file lines
nnoremap Y y$|" make Y consistant with C/D
nnoremap n nzz|" next search result and center
nnoremap N Nzz|" prev search result and center
nnoremap * *zz|" next search under cursor and center
nnoremap # #zz|" prev search under cursor and center

" copied tmux bindings
nnoremap <leader>z :call zoom#toggle()<cr>|" toggle single pane zoom
nnoremap <leader>% :vertical split<cr>|" create new vertical split
nnoremap <leader>" :split<cr>|" create new horizontal split

" fzf - see $VIMHOME/plugin/fzf.vim for more -   C-v :vsp    C-x :sp    <cr> :e
nnoremap <leader>f :FzfDefault!<cr>|" contextual open files hg>git>everything
nnoremap <leader>m :FzfMru!<cr>|" open most recently edited files
nnoremap <leader>j :Buffs<cr>|" open buffers, mru, can mash to get last buffer
nnoremap <leader>J :AllBuffs<cr>|" open buffers, including temp/help/unused
nnoremap <leader>c :Maps<cr>|" search for hotkeys

" tabs
nnoremap H :tabprev<cr>
nnoremap L :tabnext<cr>
nnoremap X :tabclose<cr>

" buffers
nnoremap <leader>bp :BuffergatorMruCyclePrev<cr>|" (b)uffer (p)rev by recency
nnoremap <leader>bn :BuffergatorMruCycleNext<cr>|" (b)uffer (n)ext by recency
nnoremap <leader>bx :bp\|bd #<cr>|" close buffer and preserve window/split

" switches
nnoremap <leader>sr :set relativenumber!<cr>|" toggle relative line ##s
nnoremap <leader>sa :AnsiEsc<cr>|" toggle ANSI escaping (color codes)
nnoremap <leader>sp :set paste!<cr>|" toggle paste mode
nnoremap <leader>sc :call conceal#toggle_conceal()<cr>|" toggle concealing chars
nnoremap <leader>sz :Goyo<cr>|" toggle distraction free mode

" sidebars
nnoremap <leader>sb :BuffergatorToggle<cr>|" toggle buffer sidebar
nnoremap <leader>sT :BuffergatorTabsToggle<cr>|" toggle tabs sidebar
nnoremap <leader>sg :TagbarToggle<cr>|" toggle tagbar ctags browser sidebar
nnoremap <leader>sn :NERDTreeToggle<cr>|" toggle NERDTree directory sidebar
nnoremap <leader>sN :NERDTreeFind<cr>|" locate current file in NERDTree
nnoremap <leader>su :GundoToggle<cr>|" toggle UndoTree undo history sidebar

" quickfix
nnoremap <leader>qq :call asyncrun#quickfix_toggle(8)<cr>|" toggle quickfix pane
nnoremap <leader>qn :cn<cr>|" quickfix next
nnoremap <leader>qp :cp<cr>|" quickfix prev
nnoremap <leader>qm :MRU<cr>|" most recently used files in quickfix

" other
vnoremap <leader>n :NarrowRegion<cr>|" open temp buffer to modify selection
noremap <leader>/ :<C-u>nohlsearch<cr>|" clear highlight for last search
noremap <C-g> :<C-u>Ranger<cr>|" start ranger file system navigator, zsh keymap

" expand `%%/` to full path of current file on command line
cnoreabbr <expr> %% expand('%:p:h')
call abbreviate#Cnoreabbr('to', 'TabooOpen', 'open tab with name')
call abbreviate#Cnoreabbr('tr', 'TabooRename', 'rename current tab')
call abbreviate#Cnoreabbr('tR', 'TabooReset', 'reset tab name to default')

" diff
" see $VIMHOME/plugin/diff.vim

" navigation
nnoremap <leader>gf :call nav#OpenInPrevSplit()<cr>
nnoremap <leader>gF :call nav#OpenInNextSplit()<cr>
nnoremap g<C-j> <C-W>J|" swap
nnoremap g<C-k> <C-W>K|" panes
nnoremap g<C-h> <C-W>H|" with
nnoremap g<C-l> <C-W>L|" g ctrl+h/j/k/l
" see vim-tmux-navigator plugin instead
" nnoremap <C-j> <C-W>j|" navigate
" nnoremap <C-k> <C-W>k|" panes
" nnoremap <C-h> <C-W>h|" with
" nnoremap <C-l> <C-W>l|" ctrl+h/j/k/l

" source locally specific vimrc if present
call util#SourceIfExists($VIMHOME . "/config/maps.local.vim")
