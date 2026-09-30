" set up actions available from fzf results
let g:fzf_action = {
  \ 'ctrl-q': function('quickfix#BuildQuickfix'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" FZF commands created by FzfFileCmdDef select from list of files, can use:
"   C-j/n=down   C-k/p=up   (S-)Tab=multi select
"   Enter=open   C-x=horiz   C-v=vert   C-t=tabs   ?=preview
" e.g.
"   call s:FzfFileCmdDef('Oldfiles', {'source': v:oldfiles})
" defines
"   :Oldfiles -> default fzf layout, toggle preview with `?`
"   :Oldfiles! -> fullscreen with preview
function! s:FzfFileCmdDef(name, options)
  call s:FzfFileCmdDefRaw(a:name, "", a:options)
endfunction

" Only need to use this if you need to not stringify to avoid freezing in
" variables that you need to read at runtime
" :call s:FzfFileCmdDef('Ls', {'source': 'ls', 'dir': expand('%')})`
" should `ls | fzf` the current file's path, but gets frozen to `pwd | fzf`
" :call s:FzfFileCmdDefRaw('Ls', "'dir': expand('%')", {'source': 'ls'})`
" gets around this by passing as a sting already, so we don't expand
function! s:FzfFileCmdDefRaw(name, rawtext, options)
  let opts = copy(a:options)

  " prepend to fzf options, which may already be string, list, or null
  let old_fzf_opts = get(opts, 'options', [])
  if type(old_fzf_opts) != type([]) | let old_fzf_opts = [old_fzf_opts] | endif
  let opts.options = ['--multi'] + old_fzf_opts

  " overrides for `:Command!`, apart from the preview that is specified inline
  let bang_opts = extend({"down": "100%"}, opts)

  let not_bang_opts = string(opts)
  let has_bang_opts = string(bang_opts)

  if len(a:rawtext) " use `rawtext` directly, do _not_ instantiate -> stringify
    let not_bang_opts = not_bang_opts[:-2] . ', ' . a:rawtext . ' }'
    let has_bang_opts = has_bang_opts[:-2] . ', ' . a:rawtext . ' }'
  endif

  execute 'command! -bang' a:name ' call fzf#run(fzf#wrap("' a:name '",
    \ <bang>0 ? fzf#vim#with_preview(' has_bang_opts ', "right")
    \         : fzf#vim#with_preview(' not_bang_opts ', "right:50%:hidden", "?")))'
endfunction

" FZF_DEFAULT_COMMAND - contextual project files -> fzf
call s:FzfFileCmdDef('FzfDefault', {})
nnoremap <leader>Ff :FzfDefault<cr>
nnoremap <leader>Fpf :FzfDefault!<cr>

" all files in working dir -> fzf
call s:FzfFileCmdDef('FzfWorkingDir', {'source': 'rg --hidden --files'})
nnoremap <leader>Fw :FzfWorkingDir<cr>
nnoremap <leader>Fpw :FzfWorkingDir!<cr>

" all files in current buffer's dir -> fzf
call s:FzfFileCmdDefRaw('FzfLocalDir',
      \'"dir": expand("%:p:h")',
      \{ 'source': 'rg --hidden --files' })
nnoremap <leader>Fl :FzfLocalDir<cr>
nnoremap <leader>Fpl :FzfLocalDir!<cr>

" git edited files -> fzf
call s:FzfFileCmdDef('FzfGit', {'source': 'git ls-files'})
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
