if !exists('g:plugs')
  echomsg 'vim-plug did not register any plugins'
  cquit
endif

let s:missing = []
for [s:name, s:plug] in items(g:plugs)
  if !has_key(s:plug, 'uri')
    continue
  endif
  let s:dir = get(s:plug, 'dir', '')
  if !isdirectory(s:dir) || !isdirectory(s:dir . '/.git')
    call add(s:missing, s:name)
  endif
endfor

if !empty(s:missing)
  for s:name in s:missing
    echomsg 'Vim plugin was not installed: ' . s:name
  endfor
  cquit
endif
