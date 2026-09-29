" PlugInstall skips existing checkouts. Update only plugins with commit pins;
" branch plugins retain their installed revision during a routine restore.
let s:pinned = []
for [s:name, s:plug] in items(g:plugs)
  if !empty(get(s:plug, 'commit', ''))
    let s:git = 'git --no-optional-locks --no-replace-objects -C ' . shellescape(s:plug.dir)
    let s:actual = trim(system(s:git . ' rev-parse --verify HEAD'))
    let s:actual_failed = v:shell_error
    let s:expected = trim(system(s:git . ' rev-parse --verify ' . shellescape(s:plug.commit . '^{commit}')))
    if s:actual_failed || v:shell_error || s:actual !=# s:expected
      call add(s:pinned, s:name)
    endif
  endif
endfor
if !empty(s:pinned)
  execute 'PlugUpdate --sync ' . join(map(s:pinned, 'fnameescape(v:val)'), ' ')
endif
