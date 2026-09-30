" Expand named environment variables without expanding filename metacharacters.
function! s:EnvironmentValue(variable) abort
  let value = getenv(strpart(a:variable, 1))
  return value is v:null ? a:variable : value
endfunction

function! s:CursorFile() abort
  return substitute(expand('<cfile>'), '\$\h\w*',
    \ '\=s:EnvironmentValue(submatch(0))', 'g')
endfunction

function! nav#OpenInPrevSplit()
  let cfile = s:CursorFile()
  wincmd p
  execute "edit " . fnameescape(cfile)
  wincmd w
endfunction

function! nav#OpenInNextSplit()
  let cfile = s:CursorFile()
  wincmd w
  execute "edit " . fnameescape(cfile)
  wincmd p
endfunction
