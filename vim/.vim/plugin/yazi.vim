function! s:YaziOpen(...) abort
  if !executable('yazi')
    echohl ErrorMsg
    echomsg "yazi not found - run 'make mise-tools' from your dotfiles repo"
    echohl None
    return
  endif

  let l:entry = a:0 >= 1 && !empty(a:1) ? expand(a:1) : s:DefaultEntry()
  let l:cwd_file = tempname()
  let l:chooser_file = tempname()
  let l:cmd = ['yazi', '--cwd-file', l:cwd_file, '--chooser-file', l:chooser_file]

  if !empty(l:entry)
    call add(l:cmd, l:entry)
  endif

  botright 15new
  call term_start(l:cmd, {
        \ 'exit_cb': function('s:OnYaziExit', [l:cwd_file, l:chooser_file]),
        \ 'term_finish': 'close',
        \ })
  startinsert
endfunction

function! s:DefaultEntry() abort
  let l:path = expand('%:p')

  if empty(l:path)
    return getcwd()
  endif

  if isdirectory(l:path)
    return l:path
  endif

  return fnamemodify(l:path, ':h')
endfunction

function! s:OnYaziExit(cwd_file, chooser_file, job, status) abort
  let l:cwd = filereadable(a:cwd_file) ? join(readfile(a:cwd_file), "\n") : ''
  let l:chosen = filereadable(a:chooser_file) ? readfile(a:chooser_file) : []

  call delete(a:cwd_file)
  call delete(a:chooser_file)

  if !empty(l:cwd) && isdirectory(l:cwd)
    execute 'cd ' . fnameescape(l:cwd)
  endif

  if empty(l:chosen)
    return
  endif

  execute 'edit ' . fnameescape(fnamemodify(l:chosen[0], ':p'))

  for l:file in l:chosen[1:]
    execute 'argadd ' . fnameescape(fnamemodify(l:file, ':p'))
  endfor
endfunction

command! -nargs=? Yazi call s:YaziOpen(<f-args>)
