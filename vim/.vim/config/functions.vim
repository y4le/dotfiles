" HELPER FUNCTIONS

" source this vimrc file if it exists
function! SourceIfExists(file)
  if filereadable(expand(a:file))
    exe 'source' a:file
  endif
endfunction

" fzf all files in cwd
function! FzfCwd()
  let nerdRoot = g:NERDTree.ForCurrentTab().getRoot().path.str()
  call fzf#run({ 'source': 'rg --files --hidden', 'dir': nerdRoot })
endfunction

" An action can be a reference to a function that processes selected lines
function! BuildQuickfix(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

" source locally specific vimrc if present
call SourceIfExists("~/.vim/config/functions.local.vim")
