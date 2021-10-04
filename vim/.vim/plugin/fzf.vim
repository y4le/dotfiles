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

" FZF_DEFAULT_COMMAND - contextual hg/git/all files -> fzf
call s:FzfFileCmdDef('FzfDefault', {'source': $FZF_DEFAULT_COMMAND})
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

" hg edited files -> fzf
call s:FzfFileCmdDef('FzfHg', {'source': 'hg files'})
nnoremap <leader>Fh :FzfHg<cr>
nnoremap <leader>Fph :FzfHg!<cr>

" most recently used files -> fzf
call s:FzfFileCmdDef('FzfMru', {'source': 'tail -n +2 ' . MRU_File})
nnoremap <leader>Fm :FzfMru<cr>
nnoremap <leader>Fpm :FzfMru!<cr>
" v:oldfiles is vim's builin equivalent
call s:FzfFileCmdDefRaw('Oldfiles',
  \ '"source": map(v:oldfiles, "expand(v:val)")',
  \ { 'down': '100%', 'options': ['--multi', '--preview', 'bat {} || cat {}'] })

" open buffers -> fzf
call s:FzfFileCmdDefRaw('Buffs',
  \ '"source": map(filter(copy(g:buffergator_mru[1:]), "bufexists(v:val)"), "bufname(v:val)")',
  \ { 'down': '100%', 'options': ['--multi', '--preview', 'bat {} || cat {}'] })
nnoremap <leader>Fb :Buffs<cr>
nnoremap <leader>Fpb :Buffs!<cr>

call s:FzfFileCmdDefRaw('AllBuffs',
  \ '"source": map(range(1, bufnr("$")), "bufname(v:val)")',
  \ { 'down': '100%', 'options': ['--multi', '--preview', 'bat {} || cat {}'] })
nnoremap <leader>FB :AllBuffs<cr>
nnoremap <leader>FpB :AllBuffs!<cr>

" available keymaps (optional query) -> fzf
function! g:FzfMaps(...)
  " display maps, restricted to matches of first arg if provided
  let l:query = a:0 >= 1 ? {'options':'--query '. a:1} : {}
  call fzf#vim#maps('n', l:query)
endfunction
nnoremap <leader><leader> :call g:FzfMaps('^\<Space\>')<cr>
