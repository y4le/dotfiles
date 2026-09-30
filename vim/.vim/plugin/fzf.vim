" set up actions available from fzf results
let g:fzf_action = {
  \ 'ctrl-q': function('quickfix#BuildQuickfix'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" File pickers support multi-selection and split/tab actions.
" In the normal layout, ? toggles the preview.
" A bang uses the fullscreen layout with the preview visible.
function! s:Files(name, bang, options) abort
  let opts = copy(a:options)
  let opts.options = ['--multi']
  if a:bang
    let opts.down = '100%'
  endif
  let preview = a:bang
    \ ? fzf#vim#with_preview(opts, 'right')
    \ : fzf#vim#with_preview(opts, 'right:50%:hidden', '?')
  call fzf#run(fzf#wrap(a:name, preview))
endfunction

" FZF_DEFAULT_COMMAND - contextual project files -> fzf
command! -bar -bang FzfDefault call s:Files('FzfDefault', <bang>0, {})
nnoremap <leader>Ff :FzfDefault<cr>
nnoremap <leader>Fpf :FzfDefault!<cr>

" all files in working dir -> fzf
command! -bar -bang FzfWorkingDir call s:Files('FzfWorkingDir', <bang>0, {'source': 'rg --hidden --files'})
nnoremap <leader>Fw :FzfWorkingDir<cr>
nnoremap <leader>Fpw :FzfWorkingDir!<cr>

" all files in current buffer's dir -> fzf
command! -bar -bang FzfLocalDir call s:Files('FzfLocalDir', <bang>0,
  \ {'dir': expand('%:p:h'), 'source': 'rg --hidden --files'})
nnoremap <leader>Fl :FzfLocalDir<cr>
nnoremap <leader>Fpl :FzfLocalDir!<cr>

" git tracked files -> fzf
command! -bar -bang FzfGit call s:Files('FzfGit', <bang>0, {'source': 'git ls-files'})
nnoremap <leader>Fg :FzfGit<cr>
nnoremap <leader>Fpg :FzfGit!<cr>

" Recent files combine Vim's persisted history with this session's buffers.
" Keep both command names, with one picker and no separate MRU state file.
function! s:RecentFiles(bang) abort
  call fzf#vim#history(fzf#vim#with_preview({},
    \ a:bang ? 'right' : 'right:50%:hidden', '?'), a:bang)
endfunction
command! -bar -bang FzfMru call s:RecentFiles(<bang>0)
command! -bar -bang Oldfiles call s:RecentFiles(<bang>0)
nnoremap <leader>Fm :FzfMru<cr>
nnoremap <leader>Fpm :FzfMru!<cr>

" fzf.vim tracks buffer recency and selects by number, including unnamed
" buffers. AllBuffs also includes existing unlisted buffers (help, scratch).
function! s:Buffers(all, bang) abort
  let args = ['']
  if a:all
    call add(args, map(getbufinfo(), 'v:val.bufnr'))
  endif
  call extend(args, [fzf#vim#with_preview({'placeholder': '{1}'},
    \ a:bang ? 'right' : 'right:50%:hidden', '?'), a:bang])
  call call('fzf#vim#buffers', args)
endfunction
command! -bar -bang Buffs call s:Buffers(0, <bang>0)
command! -bar -bang AllBuffs call s:Buffers(1, <bang>0)
nnoremap <leader>Fb :Buffs<cr>
nnoremap <leader>Fpb :Buffs!<cr>
nnoremap <leader>FB :AllBuffs<cr>
nnoremap <leader>FpB :AllBuffs!<cr>

" available keymaps (optional query) -> fzf
function! g:FzfMaps(...)
  " display maps, restricted to matches of first arg if provided
  let l:query = a:0 >= 1 ? {'options':'--query '. a:1} : {}
  call fzf#vim#maps('n', l:query)
endfunction
nnoremap <leader><leader> :call g:FzfMaps('^\<Space\>')<cr>
