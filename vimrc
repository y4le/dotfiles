execute pathogen#infect()
set history=700
filetype plugin on
filetype indent on
syntax on

set autoread

let mapleader = ","
let g:mapleader = ","

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

map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
