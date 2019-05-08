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

" source locally specific vimrc if present
call SourceIfExists("~/.vim/config/settings.local.vim")
