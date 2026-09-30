" VIM-PLUG
if !filereadable($VIMHOME . '/autoload/plug.vim')
  echomsg "plug.vim not found - run 'make vim-plugins' from your dotfiles repo"
  finish
endif

call plug#begin(expand('~/.local/share/vim/plugged'))
" Plug 'gpanders/vim-man' " :Man pages in vim

" theme plugins
Plug 'ErichDonGubler/vim-sublime-monokai' " :colorscheme sublimemonokai
Plug 'vim-airline/vim-airline' " status line replacement

" ui navigation plugins
Plug 'christoomey/vim-tmux-navigator' " C-h/j/k/l moves vim/tmux panes
Plug 'paulbkim-dev/vim-herdr-navigation', {'commit': '79679dacc791f70fc34de8b29a3cf9706c0f5b2f'}
Plug 'dhruvasagar/vim-zoom' " <leader>z zooms pane like tmux

" motion / target plugins
Plug 'tpope/vim-surround' " surround nouns, e.g. ysiw[ -> put [ around word
Plug 'wellle/targets.vim' " di' -> delete inside '

" search plugins
Plug 'markonm/traces.vim' " %s/live preview/substitute commands/

" sidebar / gutter plugins
Plug 'mhinz/vim-signify' " git gutter
Plug 'preservim/nerdtree' " sidebar showing file navigator

" ctags
" Plug 'ludovicchabant/vim-gutentags' " auto manage ctags
" Plug 'preservim/tagbar' " sidebar showing structure using ctags

" completion / linting plugins
Plug 'dense-analysis/ale' " async linting engine

" vimwiki - see $VIMHOME/plugin/wiki.vim
Plug 'vimwiki/vimwiki' " personal wiki: leader w w -> wiki
Plug 'junegunn/vim-easy-align' " align columns

" fzf plugins
Plug 'junegunn/fzf' " fzf runtime; the binary comes from mise
Plug 'junegunn/fzf.vim' " fuzzy finder integration

" VCS plugins
Plug 'tpope/vim-fugitive' " git integration

" system plugins
Plug 'gioele/vim-autoswap' " auto deal with swap in common situations
Plug 'vim-scripts/restore_view.vim' " save/restore folds/cursor position

" language specific plugins
" Plug 'psf/black', { 'for': 'python' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" source local overrides if present; inside init block so you can Plug 'eg.vim'
call util#SourceIfExists($VIMHOME . "/config/plugins.local.vim")

call plug#end()


" PLUGIN CONFIG

let g:signify_vcs_list = ['git'] " vim-signify plugin - only check these VCS

" airline - tab/status line
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
