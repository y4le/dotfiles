" quick toggle minimal/maximal saving options
command! SessionSaveMin :set sessionoptions=buffers,tabpages
command! SessionSaveMax :set sessionoptions=blank,buffers,curdir,folds,globals,help,options,tabpages,winsize

" (s)ession (s)ave - :ss/dotfiles
cnoreabbrev <expr> ss getcmdtype() ==# ':' && getcmdline() ==# 'ss' ? 'mks! ' . fnameescape($VIMSTATE . '/sessions') : 'ss'

" (s)ession (l)oad - :sl/dotfiles
cnoreabbrev <expr> sl getcmdtype() ==# ':' && getcmdline() ==# 'sl' ? 'source ' . fnameescape($VIMSTATE . '/sessions') : 'sl'


" :Sessions - saved vim sessions -> fzf
function! s:FzfSessionSink(src_file) abort
  execute 'source ' . fnameescape($VIMSTATE . '/sessions/' . a:src_file)
endfunction

function! s:Sessions() abort
  let directory = $VIMSTATE . '/sessions'
  let files = isdirectory(directory) ? readdir(directory) : []
  call filter(files, 'v:val !~# "^\\." && filereadable(directory . "/" . v:val)')
  call fzf#run({
    \ 'source': files,
    \ 'sink': function('<sid>FzfSessionSink'),
    \ 'options': '+m --prompt="Restore Session> "'
    \ })
endfunction
command! Sessions call s:Sessions()
