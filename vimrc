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

" general plugins
Plug 'Xuyuanp/nerdtree-git-plugin' " git indicators for nerdtree
Plug 'Yggdroot/indentLine' " show indentation with vertical lines like sublime
Plug 'andymass/vim-matchup' " better % motion
Plug 'dhruvasagar/vim-table-mode' " table mode
Plug 'easymotion/vim-easymotion' " jump around with `Space j/k`
Plug 'haya14busa/incsearch.vim' " show all incremental search results while typing
Plug 'itchyny/lightline.vim' " status line
Plug 'jeffkreeftmeijer/vim-numbertoggle' " hybrid to static line #s on un/focus
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fzf setup
Plug 'junegunn/fzf.vim' " fuzzy finder integration
Plug 'maralla/completor.vim' " code completion
Plug 'markonm/traces.vim' " %s/live preview/substitute commands/
Plug 'mhinz/vim-signify' " git gutter
Plug 'rhysd/clever-f.vim' " repeaded f keeps going forward
Plug 'romainl/vim-cool' " stop highlighting after searching
Plug 'scrooloose/nerdtree' " file navigator sidebar
Plug 'takac/vim-hardtime' " rate limit h/j/k/l to get better with :HardTimeToggle
Plug 'tomtom/tcomment_vim' " commenting plugin
Plug 'w0rp/ale' " async linting engine
Plug 'wellle/targets.vim' " di' -> delete inside '
Plug 'mbbill/undotree' " access full undo history

" language plugins
Plug 'tpope/vim-rails'
Plug 'vim-ruby/vim-ruby'

call plug#end()


" THEME
colorscheme sublimemonokai " the apple of my monokeye

" SYSTEM
set autoread " auto read external changes made to file
set hidden " buffers hidden when abandoned, editor survives buffer close
set nobackup " version control has arrived
set noswapfile " git will save us
set undofile " keep undo history
set undodir=~/.vim/.undo// " move undo history to one place
set history=1000 " increase vim history a bit
set wildmenu " command mode tab-completion
set cmdheight=2 " command bar is 2 lines high

" LOOK
syntax on " enable syntax highlighting
filetype plugin on " enable filetype plugins
filetype indent on " enable filetype indentation

set number relativenumber " hybrid-relative line numbering
set ruler " row/col readout in the bottom right command bar
set colorcolumn=80 " highlight col 80

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
nnoremap <C-j> <C-W>j|" move
nnoremap <C-k> <C-W>k|" panes
nnoremap <C-h> <C-W>h|" with
nnoremap <C-l> <C-W>l|" ctrl+h/j/k/l

nnoremap j gj|" j moves down visible instead of file lines
nnoremap k gk|" k moves up visible instead of file lines

let mapleader = "\<Space>" " set leader to Space
let g:mapleader = "\<Space>" " repeat leader mapping globally

nnoremap <leader>x :bd<cr>|" close buffer and close window/split
nnoremap <leader>X :bp\|bd #<cr>|" close buffer and preserve window/split
nnoremap <leader>N :enew<cr>|" new buffer

" FZF! use these `Space r`
nnoremap <leader>b :Buffers<cr>|" pick open buffers by id/filename
nnoremap <leader>n :Files<cr>|  " pick from all files in vim's root dir by filename
nnoremap <leader>l :Lines<cr>|  " find line in any open buffer
nnoremap <leader>r :Rg<cr>| " fzf+rg full text through the whole working directory

" sidebar plugins
nnoremap <leader>t :NERDTreeToggle<CR>|" toggle NERDTree directory sidebar
nnoremap <leader>u :UndotreeToggle<CR>|" toggle UndoTree undo history sidebar

" easymotion plugin
let g:EasyMotion_smartcase = 1
map <Leader>j <Plug>(easymotion-j)|" quick jump to line below
map <Leader>k <Plug>(easymotion-k)|" quick jump to line above

" set global default rg command
let g:rg_command = '
  \ rg --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,haml,config,py,cpp,c,coffee,,go,hs,rb,conf}"
  \ -g "!{.git,node_modules,vendor}/*" '

