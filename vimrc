" Auto-Install vim-plug
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

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
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fzf setup
Plug 'junegunn/fzf.vim' " fuzzy finder integration
Plug 'maralla/completor.vim' " code completion
Plug 'markonm/traces.vim' " preview substitute commands
Plug 'mhinz/vim-signify' " git gutter
Plug 'mhinz/vim-startify' " pretty start screen
Plug 'rhysd/clever-f.vim' " repeaded f keeps going forward
Plug 'romainl/vim-cool' " stop highlighting after searching
Plug 'scrooloose/nerdtree' " file navigator sidebar
Plug 'tomtom/tcomment_vim' " commenting plugin
Plug 'w0rp/ale' " async linting engine
Plug 'wellle/targets.vim' " di' -> delete inside '

" language plugins
Plug 'tpope/vim-rails'
Plug 'vim-ruby/vim-ruby'

call plug#end()


" SYSTEM
set autoread     " auto read external changes made to file
set hid          " buffers get hidden when they are abandoned
set history=1000 " increase vim history a bit
set clipboard=unnamed " allow for osx system copy paste

" turn off backup, we use version control round here
set nobackup
set nowb
set noswapfile

" enable filetype plugins
filetype plugin on
filetype indent on

" set up command pane
set wildmenu


" LOOK & FEEL
colorscheme sublimemonokai
syntax on   " enable syntax highlighting
set nu      " line numbers
set ruler   " row/col readout in the bottom right command bar
set mouse=a " mouse input allowed

" backspace is sane now
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" matching brackets
set showmatch
set mat=2

" tab settings
set expandtab
set smarttab
set shiftwidth=2
set tabstop=2


" SEARCH
set ignorecase " ignore case while searching
set smartcase " stop ignoring case if there is >0 caps
set hlsearch  " highlight search results
set incsearch " search as you type
set magic     " better regex


" MAPS
" ctrl+directin moves panes
nnoremap <C-j> <C-W>j
nnoremap <C-k> <C-W>k
nnoremap <C-h> <C-W>h
nnoremap <C-l> <C-W>l

" j/k move down/up visible lines instead of file lines
nnoremap j gj
nnoremap k gk

" set up leader
let mapleader = "\<Space>"
let g:mapleader = "\<Space>"

" close buffer with leader-x
nnoremap <leader>x :bd<cr>
nnoremap <leader>X :bp\|bd #<cr>

" new buffer with leader-N
nnoremap <leader>N :enew<cr>

" t commands for tab management
nnoremap <leader>tn :tabnew<cr>
nnoremap <leader>to :tabonly<cr>
nnoremap <leader>tc :tabclose<cr>
nnoremap <leader>tm :tabmove


" PLUGINS
" set up easymotion plugin
let g:EasyMotion_smartcase = 1
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)

" set up fzf plugin
nnoremap <C-t> :FZF<cr>
nnoremap <leader>b :Buffers<cr>
nnoremap <leader>n :Files<cr>
nnoremap <leader>l :Lines<cr>
nnoremap <leader>a :Ag<space>

let g:rg_command = '
  \ rg --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,config,py,cpp,c,go,hs,rb,conf}"
  \ -g "!{.git,node_modules,vendor}/*" '

command! -bang -nargs=* F call fzf#vim#grep(g:rg_command .shellescape(<q-args>), 1, <bang>0)

" set up nerdtree plugin
nnoremap <leader>t :NERDTreeToggle<CR>
" auto open nerdtree when no file opened
" autocmd StdinReadPre * let s:std_in=1
" autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

