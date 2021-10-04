" An action can be a reference to a function that processes selected lines
function! quickfix#BuildQuickfix(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

