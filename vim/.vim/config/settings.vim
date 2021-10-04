" THEME
colorscheme sublimemonokai " the apple of my monokeye

" SYSTEM
set nocompatible " not vi compatible
set autoread " auto read external changes made to file
set hidden " buffers hidden when abandoned, editor survives buffer close
set history=10000 " increase vim history a bit
set wildmenu " command mode tab-completion
set cmdheight=1 " command bar is 1 line high
set showcmd " always show command bar
set lazyredraw " don't redraw e.g. in the middle of macros
set re=1 " use old regex engine - faster syntax highlighting - relativenumber lags otherwise

" save these things when we save a vim session (:mks ~/foo) (:source ~/foo)
set sessionoptions=blank,buffers,curdir,folds,globals,help,options,tabpages,winsize
" save these parts of view when exiting a file (:mkview ~/foo) (:loadview)
set viewoptions=cursor,folds,slash,unix
" don't save view for these files
let g:skipview_files = ['*\.vim']

" create $VIMHOME/(tmp|undo|sessions|view) if not present
for dir in ["/tmp", "/undo", "/sessions", "/view"]
  if !isdirectory($VIMHOME . dir)
    call mkdir($VIMHOME . dir, "", 0700)
  endif
endfor

set undodir^=$VIMHOME/undo//,. " save undo history here
set undofile " keep undo history

set directory^=$VIMHOME/tmp//,. " save swapfiles here
set backupdir^=$VIMHOME/tmp//,. " save backups here
set backup " keep backups

" LOOK
syntax on " enable syntax highlighting
filetype plugin on " enable filetype plugins
filetype indent on " enable filetype indentation

set number relativenumber " hybrid-relative line numbering
set ruler " row/col readout in the bottom right command bar
set colorcolumn=80 " highlight col 80
set cursorline " highlight current line
set scrolloff=5 " keep n rows on screen when moving vertically
set sidescroll=5 " keep n columns on screen when moving horizontally
set listchars+=precedes:<,extends:> " show </> when line scrolls off

set showmatch " show matching brackets (nice with %)
set matchtime=2 " for 0.2 seconds

" FEEL
set mouse=a " mouse input enabled in all modes
set clipboard=unnamed " allow for osx system copy paste

set backspace=eol,start,indent " backspace up a line or through indentation
set whichwrap+=<,>,h,l " these movements wrap over lines

" FOLDS
set foldenable " enable folds

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
set softtabstop=2 " always damnit

" source locally specific vimrc if present
call util#SourceIfExists($VIMHOME . "/config/settings.local.vim")
