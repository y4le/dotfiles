call plug#begin('~/.vim/plugged')

Plug 'vim-scripts/YankRing.vim'
Plug 'w0ng/vim-hybrid'
Plug 'tpope/vim-surround'
Plug 'junegunn/fzf.vim'
Plug 'easymotion/vim-easymotion'

call plug#end()


set history=700
filetype plugin on
filetype indent on
syntax on

set autoread

let mapleader = "\<Space>"

set wildmenu

set ruler

set cmdheight=2

set hid

set backspace=eol,start,indent
set whichwrap+=<,>,h,l
set smartcase
set hlsearch
set incsearch
set magic
set showmatch
set mat=2

set nobackup
set nowb
set noswapfile

set expandtab
set smarttab
set shiftwidth=2
set tabstop=2

nnoremap <C-j> <C-W>j
nnoremap <C-k> <C-W>k
nnoremap <C-h> <C-W>h
nnoremap <C-l> <C-W>l

nnoremap <leader>tn :tabnew<cr>
nnoremap <leader>to :tabonly<cr>
nnoremap <leader>tc :tabclose<cr>
nnoremap <leader>tm :tabmove
nnoremap <leader>N :enew<cr>
nnoremap <leader>b :Buffers<cr>
nnoremap <leader>n :Files<cr>
nnoremap <leader>l :Lines<cr>
nnoremap <leader>a :Ag<space>
nnoremap <leader><enter> /{<cr>
nnoremap <leader><s-enter> ?{<cr>
nnoremap <leader>x :bd<cr>

nnoremap j gj
nnoremap k gk
inoremap jk <ESC>

nnoremap <S-j> :bprevious<cr>
nnoremap <S-k> :bnext<cr>

let g:EasyMotion_smartcase = 1
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
