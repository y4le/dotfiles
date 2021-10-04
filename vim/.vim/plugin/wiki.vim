" setup vimwiki

let s:dir = $HOME . '/Google Drive/vimwiki/'
if !isdirectory(glob(s:dir))
  let s:dir = $HOME . '/Drive/My Drive/vimwiki/'
endif

let s:dir = fnameescape(s:dir)

let g:vim_markdown_folding_disabled = 1
let g:vimwiki_folding = ''

let s:defaults = { 'syntax': 'markdown', 'ext': '.md' }

let g:vimwiki_list = [
  \extend({}, extend(s:defaults,
    \{'path': s:dir.'work/wiki', 'path_html': s:dir.'work/html'})),
  \extend({}, extend(s:defaults,
    \{'path': s:dir.'personal/wiki', 'path_html': s:dir.'personal/html'})),
\]

" disabled in favor of custom folds (`zf`)
" let g:vimwiki_folding='list' " fold todo lists based on level

" filetype detected in $VIMHOME/filetype.vim
" filetype settings in $VIMHOME/ftplugin/wiki.vim
