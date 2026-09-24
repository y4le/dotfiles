" quick toggle minimal/maximal saving options
command! SessionSaveMin :set sessionoptions=buffers,tabpages
command! SessionSaveMax :set sessionoptions=blank,buffers,curdir,folds,globals,help,options,tabpages,winsize

" (s)ession (s)ave - :ss/dotfiles
cnoreabbrev <expr> ss getcmdtype() ==# ':' && getcmdline() ==# 'ss' ? 'mks! $VIMSTATE/sessions' : 'ss'

" (s)ession (l)oad - :sl/dotfiles
cnoreabbrev <expr> sl getcmdtype() ==# ':' && getcmdline() ==# 'sl' ? 'source $VIMSTATE/sessions' : 'sl'


" :Sessions - saved vim sessions -> fzf
function! s:FzfSessionSink(src_file)
  execute 'source ' . $VIMSTATE . '/sessions/' . a:src_file
endfunction
command! Sessions call fzf#run({
  \   'source': 'ls ' . $VIMSTATE . '/sessions',
  \   'sink': function('<sid>FzfSessionSink'),
  \   'options': '+m --prompt="Restore Session> "'
  \ })
