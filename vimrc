" VIM-PLUG
" Auto-Install vim-plug if missing
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" set up nvim vim-plug access
if has('nvim') && empty(glob('~/.config/nvim/autoload/plug.vim'))
  silent !mkdir -p ~/.config/nvim/autoload
  silent !ln -s ~/.vim/autoload/plug.vim ~/.config/nvim/autoload/plug.vim
  autocmd VimEnter * PlugInstall
endif

if has('nvim')
  call plug#begin('~/.config/nvim/plugged')
else
  call plug#begin('~/.vim/plugged')
endif

" theme plugins
Plug 'ErichDonGubler/vim-sublime-monokai' " :colorscheme sublimemonokai

" status line plugins
Plug 'itchyny/lightline.vim' " status line

" ui navigation plugins
Plug 'christoomey/vim-tmux-navigator' " ctrl+h/j/k/l navigates vim and tmux panes
Plug 'ton/vim-bufsurf' " :bp/:bn prev/next buffers LRU, not opening time based

" motion / target plugins
Plug 'andymass/vim-matchup' " better % motion
Plug 'easymotion/vim-easymotion' " space space motion -> jumps as if ## motion
Plug 'rhysd/clever-f.vim' " repeaded f keeps going forward
Plug 'wellle/targets.vim' " di' -> delete inside '

" search plugins
Plug 'haya14busa/incsearch.vim' " show all incremental search results while typing
Plug 'markonm/traces.vim' " %s/live preview/substitute commands/
Plug 'wincent/ferret' " :Ack -> multi file search | quickfix pane
Plug 'wincent/loupe' " better within file search results

" sidebar / gutter plugins
Plug 'Xuyuanp/nerdtree-git-plugin' " git indicators for nerdtree
Plug 'jeffkreeftmeijer/vim-numbertoggle' " hybrid to static line #s on un/focus
Plug 'majutsushi/tagbar' " sidebar that shows structure by using ctags
Plug 'mbbill/undotree' " access full undo history
Plug 'mhinz/vim-signify' " git gutter
Plug 'scrooloose/nerdtree' " file navigator sidebar

" ctags / completion / linting plugins
Plug 'ludovicchabant/vim-gutentags' " auto manage ctags
Plug 'maralla/completor.vim' " code completion
Plug 'ntpeters/vim-better-whitespace' " highlight trailing whitespace
Plug 'tomtom/tcomment_vim' " commenting plugin
Plug 'w0rp/ale' " async linting engine

" productivity plugins
Plug 'vimwiki/vimwiki' " personal wiki: leader w w -> wiki
Plug 'tbabej/taskwiki' " taskwarrior vimwiki integration
Plug 'powerman/vim-plugin-AnsiEsc' " colors in taskwiki

" fzf plugins
" Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fzf setup
Plug 'junegunn/fzf.vim' " fuzzy finder integration

" other plugins
Plug 'chrisbra/NrrwRgn' " emacs narrowregion - open new buffer to edit selection
Plug 'sickill/vim-pasta' " p now pastes at right indent, like ]p
Plug 'skywind3000/asyncrun.vim' " :AsyncRun :AsyncStop commands to async :!cmd

" ruby plugins
Plug 'AndrewRadev/splitjoin.vim' " gS single->multiline  gJ multi->singleline
Plug 'itmammoth/run-rspec.vim' " run ruby specs e.g. ' sl' -> run spec on line
Plug 'tpope/vim-rails'
Plug 'vim-ruby/vim-ruby'

" web plugins
Plug 'kchmck/vim-coffee-script' " coffeescript support

call plug#end()


" THEME
colorscheme sublimemonokai " the apple of my monokeye

" SYSTEM
set nocompatible " not vi compatible
set autoread " auto read external changes made to file
set hidden " buffers hidden when abandoned, editor survives buffer close
set nobackup " version control has arrived
set noswapfile " git will save us
set undofile " keep undo history
set undodir=~/.vim/.undo// " move undo history to one place
set history=1000 " increase vim history a bit
set wildmenu " command mode tab-completion
set cmdheight=2 " command bar is 2 lines high
set re=1 " use old regex engine - faster syntax highlighting - relativenumber lags otherwise

" LOOK
syntax on " enable syntax highlighting
filetype plugin on " enable filetype plugins
filetype indent on " enable filetype indentation

set number relativenumber " hybrid-relative line numbering
set ruler " row/col readout in the bottom right command bar
set colorcolumn=80 " highlight col 80
set scrolloff=5 " keep buffer of lines above and below cursor

set showmatch " show matching brackets (nice with %)
set matchtime=2 " for 0.2 seconds

" FEEL
set mouse=a " mouse input enabled in all modes
set clipboard=unnamed " allow for osx system copy paste

set backspace=eol,start,indent " backspace up a line or through indentation
set whichwrap+=<,>,h,l " these movements wrap over lines

" SEARCH
set ignorecase " ignore case while searching
set smartcase " stop ignoring case if >0 capitals
set hlsearch " highlight search results
set incsearch " search as you type - incsearch plugin
set magic " better regex

" TABS
set expandtab " tabs -> spaces
set smarttab " smart about where to tab stop
set shiftwidth=2 " always 2 spaces
set tabstop=2 " I said always

" MAPS
nnoremap ; :|" easier command mode access

nnoremap <C-j> <C-W>j|" move
nnoremap <C-k> <C-W>k|" panes
nnoremap <C-h> <C-W>h|" with
nnoremap <C-l> <C-W>l|" ctrl+h/j/k/l

nnoremap j gj|" j moves down visible instead of file lines
nnoremap k gk|" k moves up visible instead of file lines

let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

nnoremap <leader>bx :bd<cr>|" close buffer and close window/split
nnoremap <leader>bX :bp\|bd #<cr>|" close buffer and preserve window/split
nnoremap <leader>bN :enew<cr>|" new buffer

" fzf so good! use these
nnoremap <leader>bb :Buffers<cr>|" pick open buffers by id/filename
nnoremap <leader>j :GFiles<cr>|" pick from all files in git project by filename
nnoremap <leader>n :Files<cr>|" pick from all files in vim's root dir by filename
nnoremap <leader>l :Lines<cr>|" find line in any open buffer
nnoremap <leader>r :Rg<cr>|" fulltext find in all files in the base dir
nnoremap <leader>g :Tags<cr>|" tags in project
nnoremap <leader>G :BTags<cr>|" tags in current buffer

" toggles
nnoremap <leader>tt :TagbarToggle<CR>|"   toggle tagbar ctags browser sidebar
nnoremap <leader>tn :NERDTreeToggle<CR>|" toggle NERDTree directory sidebar
nnoremap <leader>tu :UndotreeToggle<CR>|" toggle UndoTree undo history sidebar
nnoremap <leader>tr :set relativenumber!<CR>|" toggle relative line ##s

" run-rspec plugin
let g:run_rspec_result_lines = 20
nnoremap <leader>sl :RunSpecLine<CR>|" run nearest rspec test
nnoremap <leader>sf :RunSpec<CR>|" run current rspec file
nnoremap <leader>sr :RunSpecLastRun<CR>|" re-run last specs
nnoremap <leader>sc :RunSpecCloseResult<CR>| " close rspec result

" quickfix
nnoremap <leader>qq :call asyncrun#quickfix_toggle(8)<CR>|" toggle quickfix pane
nnoremap <leader>qn :cn<CR>|" quickfix next
nnoremap <leader>qp :cp<CR>|" quickfix prev

" auto open quickfix pane when it gets new text
augroup vimrc
  autocmd QuickFixCmdPost * call asyncrun#quickfix_toggle(8, 1)
augroup END

let g:EasyMotion_smartcase = 1 " easymotion plugin ignore case if nocaps
let g:signify_vcs_list = ['git', 'hg'] " vim-signify plugin - only check these VCS
let g:strip_whitespace_on_save = 1 " vim-better-whitespace plugin - strip on save
let g:gutentags_cache_dir='~/vim/.tags' " keep ctags in one place

" setup rg
set grepprg=rg\ --vimgrep\ --no-heading\ -S
set grepformat=%f:%l:%c:%m,%f:%l:%m
let g:rg_command = '
  \ rg --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,haml,config,py,cpp,c,coffee,go,hs,rb,conf}"
  \ -g "!{.git,node_modules,vendor,.venv}/*" '

" setup fzf
set rtp+=/usr/local/opt/fzf

" An action can be a reference to a function that processes selected lines
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

nnoremap <leader>f :FZF<cr>|" pick from all files, actions below
let g:fzf_action = {
  \ 'ctrl-q': function('s:build_quickfix_list'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" setup vimwiki
let g:vimwiki_list = [{'path':'~/vimwiki/wiki', 'path_html':'~/vimwiki/html'}]
