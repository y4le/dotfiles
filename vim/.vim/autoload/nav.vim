function! nav#OpenInPrevSplit()
  let cfile = expand("<cfile>")
  wincmd p
  execute "edit " . cfile
  wincmd w
endfunction

function! nav#OpenInNextSplit()
  let cfile = expand("<cfile>")
  wincmd w
  execute "edit " . cfile
  wincmd p
endfunction
