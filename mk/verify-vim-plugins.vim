if !exists('g:plugs')
  echomsg 'vim-plug did not register any plugins'
  cquit
endif

let s:missing = []
let s:mismatched = []
for [s:name, s:plug] in items(g:plugs)
  if !has_key(s:plug, 'uri')
    continue
  endif
  let s:dir = get(s:plug, 'dir', '')
  if !isdirectory(s:dir) || !isdirectory(s:dir . '/.git')
    call add(s:missing, s:name)
    continue
  endif
  let s:pin = get(s:plug, 'commit', '')
  if !empty(s:pin)
    let s:git = 'git --no-optional-locks --no-replace-objects -C ' . shellescape(s:dir)
    let s:actual = trim(system(s:git . ' rev-parse --verify HEAD'))
    let s:actual_failed = v:shell_error
    let s:expected = trim(system(s:git . ' rev-parse --verify ' . shellescape(s:pin . '^{commit}')))
    if s:actual_failed || v:shell_error || s:actual !=# s:expected
      call add(s:mismatched, s:name . ': expected ' . s:pin . ', got ' . s:actual)
    endif
  endif
endfor

if !empty(s:missing)
  for s:name in s:missing
    echomsg 'Vim plugin was not installed: ' . s:name
  endfor
  cquit
endif

if !empty(s:mismatched)
  for s:message in s:mismatched
    echomsg 'Vim plugin commit mismatch: ' . s:message
  endfor
  cquit
endif
