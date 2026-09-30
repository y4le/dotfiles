" An action can be a reference to a function that processes selected lines
function! quickfix#BuildQuickfix(lines)
  call setqflist(map(copy(a:lines), '{ "filename": (v:val[:1] ==# "~/" ? $HOME . v:val[1:] : fnamemodify(v:val, ":p")) }'))
  copen
  cc
endfunction
