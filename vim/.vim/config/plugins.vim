" VIM-PLUG
" Auto-Install vim-plug if missing
if empty(glob($VIMHOME . '/autoload/plug.vim'))
  silent !curl -fLo $VIMHOME/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" set up nvim vim-plug access
if has('nvim') && empty(glob('~/.config/nvim/autoload/plug.vim'))
  silent !mkdir -p ~/.config/nvim/autoload
  silent !ln -s $VIMHOME/autoload/plug.vim ~/.config/nvim/autoload/plug.vim
  autocmd VimEnter * PlugInstall
endif

if has('nvim')
  call plug#begin('~/.config/nvim/plugged')
else
  call plug#begin($VIMHOME . '/plugged')
  Plug 'gpanders/vim-man' " :Man pages in vim, nvim builtin
endif

" theme plugins
Plug 'ErichDonGubler/vim-sublime-monokai' " :colorscheme sublimemonokai
Plug 'vim-airline/vim-airline' " status line replacement

" ui navigation plugins
Plug 'christoomey/vim-tmux-navigator' " C-h/j/k/l moves vim/tmux panes
Plug 'dhruvasagar/vim-zoom' " <leader>z zooms pane like tmux
Plug 'francoiscabrol/ranger.vim' " G-g file system navigator
Plug 'gcmt/taboo.vim' " better tabline / rename tabs
Plug 'chrisbra/unicode.vim' " unicode search / completion

" command plugins
Plug 'chrisbra/NrrwRgn' " <leader>n - selection is opened in temp buffer to edit
Plug 'junegunn/goyo.vim' " minimal distraction writing
Plug 'junegunn/vim-peekaboo' " show registers when about to use
Plug 'sickill/vim-pasta' " p now pastes at right indent, like ]p

" motion / target plugins
Plug 'tpope/vim-surround' " surround nouns, e.g. ysiw[ -> put [ around word
Plug 'wellle/targets.vim' " di' -> delete inside '
Plug 'jeetsukumaran/vim-indentwise' " [= / ]= -> prev/next equal indent

" search plugins
Plug 'haya14busa/incsearch.vim' " show all incremental search results while typing
Plug 'markonm/traces.vim' " %s/live preview/substitute commands/
Plug 'wincent/ferret' " :Ack -> multi file search | quickfix pane

" sidebar / gutter plugins
Plug 'jeetsukumaran/vim-buffergator' " sidebar showing buffer list
Plug 'jeffkreeftmeijer/vim-numbertoggle' " hybrid to static line #s on un/focus
Plug 'mhinz/vim-signify' " git gutter
Plug 'scrooloose/nerdtree' " sidebar showing file navigator
Plug 'sjl/gundo.vim' " sidebar showing full undo history

" " ctags
" Plug 'ludovicchabant/vim-gutentags' " auto manage ctags
Plug 'majutsushi/tagbar' " sidebar showing structure using ctags

" completion / linting plugins
" Plug 'maralla/completor.vim' " code completion
" Plug 'Valloric/YouCompleteMe' " code completion
Plug 'ntpeters/vim-better-whitespace' " highlight trailing whitespace
Plug 'tomtom/tcomment_vim' " commenting plugin
Plug 'w0rp/ale' " async linting engine

" vimwiki - see $VIMHOME/plugin/wiki.vim
" Plug 'tbabej/taskwiki' " taskwarrior vimwiki integration
Plug 'powerman/vim-plugin-AnsiEsc' " colors in taskwiki
Plug 'vimwiki/vimwiki' " personal wiki: leader w w -> wiki
Plug 'mattn/calendar-vim' " what is said on the tin, calendar in vim
Plug 'junegunn/vim-easy-align' " align columns

" fzf plugins
Plug '~/.zplug/repos/junegunn/fzf' " fzf setup
Plug 'junegunn/fzf.vim' " fuzzy finder integration

" VCS plugins
Plug 'tpope/vim-fugitive' " git integration
Plug 'ludovicchabant/vim-lawrencium' " mercurial integration

" system plugins
Plug 'HerringtonDarkholme/w3m.vim' " w3m cli browser plugin
Plug 'gioele/vim-autoswap' " auto deal with swap in common situations
Plug 'kana/vim-submode' " define modes that temporarily override maps
Plug 'rkitover/vimpager' " use vim as terminal $PAGER
Plug 'skywind3000/asyncrun.vim' " :AsyncRun :AsyncStop commands to async :!cmd
Plug 'vim-scripts/restore_view.vim' " save/restore folds/cursor position
Plug 'yegappan/mru' " list most recently used files, cleaner than v:oldfiles

" language specific plugins
Plug 'l04m33/vlime', { 'rtp': 'vim', 'for': ['clojure', 'lisp'] }
Plug 'tpope/vim-rails', { 'for': 'ruby' }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
Plug 'psf/black', { 'for': 'python' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'kchmck/vim-coffee-script', { 'for': 'coffee' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" source local overrides if present; inside init block so you can Plug 'eg.vim'
call util#SourceIfExists($VIMHOME . "/config/plugins.local.vim")

call plug#end()



" PLUGIN CONFIG

let g:peekaboo_prefix = '<leader>'
let g:EasyMotion_smartcase = 1 " easymotion plugin ignore case if nocaps
let g:signify_vcs_list = ['git', 'hg'] " vim-signify plugin - only check these VCS
let g:strip_whitespace_on_save = 1 " vim-better-whitespace plugin - strip on save
let g:gutentags_cache_dir='~/vim/.tags' " keep ctags in one place
let g:ycm_filetype_blacklist=extend(get(g:, 'ycm_filetype_blacklist', {}),
  \ {'cpp': 1, 'c': 1, 'md': 1, 'markdown':1, 'tar':1, 'vimwiki':1})
let g:better_whitespace_filetypes_blacklist=
  \ ['diff', 'gitcommit', 'hgcommit', 'unite', 'qf', 'help', 'markdown', 'w3m']

" prevent plugin maps
let g:buffergator_suppress_keymaps = 1
let g:ranger_map_keys = 0
let g:FerretMap = 0
let g:lawrencium_define_mappings = 0
let g:w3m#disable_default_keymap = 1

" airline - tab/status line
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'

" submodes
" see $VIMHOME/plugin/resize_mode
" setup airline to show submode
let g:airline_section_y = '%{submode#current()}'
let g:submode_always_show_submode = 1 " make submode status available to airline

" setup goyo
let g:goyo_height='100%'
let g:goyo_margin_top = 0
let g:goyo_margin_bottom = 0

" setup mru
let MRU_File = $VIMHOME . '/mru_files'
let MRU_Max_Entries = 1000

" setup vimpager
let g:vimpager = { 'ansiesc': 1 } " parse ansi color codes
let g:less = { 'enabled': 0 } " disable less keymaps
