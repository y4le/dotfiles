" Keep ordinary Markdown outside configured wiki roots.
let g:vimwiki_global_ext = 0

" setup vimwiki

if exists('g:vimwiki_root') && !empty(g:vimwiki_root)
  let s:root = g:vimwiki_root
elseif !empty($VIMWIKI_ROOT)
  let s:root = $VIMWIKI_ROOT
else
  let s:root = $HOME . '/vimwiki'
endif
let s:root = substitute(fnamemodify(s:root, ':p'), '[/\\]\+$', '', '')

let g:vimwiki_folding = ''

let s:defaults = { 'syntax': 'markdown', 'ext': '.md' }

let g:vimwiki_list = [
  \extend({}, extend(s:defaults,
    \{'path': s:root.'/work/wiki', 'path_html': s:root.'/work/html'})),
  \extend({}, extend(s:defaults,
    \{'path': s:root.'/personal/wiki', 'path_html': s:root.'/personal/html'})),
\]

" disabled in favor of custom folds (`zf`)
" let g:vimwiki_folding='list' " fold todo lists based on level

" filetype detected in $VIMHOME/filetype.vim
" filetype settings in $VIMHOME/ftplugin/wiki.vim
