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
" Plug 'ludovicchabant/vim-gutentags' " auto manage ctags
Plug 'maralla/completor.vim' " code completion
Plug 'ntpeters/vim-better-whitespace' " highlight trailing whitespace
Plug 'tomtom/tcomment_vim' " commenting plugin
Plug 'w0rp/ale' " async linting engine

" productivity plugins
Plug 'vimwiki/vimwiki' " personal wiki: leader w w -> wiki
Plug 'tbabej/taskwiki' " taskwarrior vimwiki integration
Plug 'powerman/vim-plugin-AnsiEsc' " colors in taskwiki

" fzf plugins
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fzf setup
Plug 'junegunn/fzf.vim' " fuzzy finder integration

" VCS plugins
Plug 'tpope/vim-fugitive' " git integration

" other plugins
Plug 'chrisbra/NrrwRgn' " emacs narrowregion - open new buffer to edit selection
Plug 'sickill/vim-pasta' " p now pastes at right indent, like ]p
Plug 'skywind3000/asyncrun.vim' " :AsyncRun :AsyncStop commands to async :!cmd

" " lisp plugins
" Plug 'l04m33/vlime', { 'rtp': 'vim' } " common lisp environment
"
" " ruby plugins
" Plug 'AndrewRadev/splitjoin.vim' " gS single->multiline  gJ multi->singleline
" Plug 'itmammoth/run-rspec.vim' " run ruby specs e.g. ' sl' -> run spec on line
" Plug 'tpope/vim-rails'
" Plug 'vim-ruby/vim-ruby'
"
" " web plugins
" Plug 'kchmck/vim-coffee-script' " coffeescript support

" source locally specific vimrc if present
call SourceIfExists("~/.vim/config/plugins.local.vim")

call plug#end()


" LOCAL PLUGINS
call SourceIfExists("~/.vim/plugins/cpst.vim")


" PLUGIN CONFIG

" auto open quickfix pane when it gets new text
augroup vimrc
  autocmd QuickFixCmdPost * call asyncrun#quickfix_toggle(8, 1)
augroup END

let g:EasyMotion_smartcase = 1 " easymotion plugin ignore case if nocaps
let g:signify_vcs_list = ['git', 'hg'] " vim-signify plugin - only check these VCS
let g:strip_whitespace_on_save = 1 " vim-better-whitespace plugin - strip on save
let g:gutentags_cache_dir='~/vim/.tags' " keep ctags in one place
nmap <leader>A <Plug>(FerretAcks)

" setup rg
set grepprg=rg\ --vimgrep\ --no-heading\ -S
set grepformat=%f:%l:%c:%m,%f:%l:%m
let g:rg_command = '
  \ rg --hidden --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,haml,config,py,cpp,c,coffee,go,hs,rb,conf,java}"
  \ -g "!{.git,node_modules,vendor,.venv}/*" '

" setup fzf
set rtp+=/usr/bin/fzf

nnoremap <leader>f :FZF<cr>|" pick from all files, actions below
let g:fzf_action = {
  \ 'ctrl-q': function('BuildQuickfix'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" setup vimwiki
let g:vimwiki_list = [{'path':'~/vimwiki/wiki', 'path_html':'~/vimwiki/html'}]
