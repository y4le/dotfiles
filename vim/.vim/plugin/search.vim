" Search related helpers

set grepprg=rg\ --vimgrep\ --no-heading\ -S
set grepformat=%f:%l:%c:%m,%f:%l:%m

let g:rg_root_command = 'rg
  \ --column --line-number --no-heading --fixed-strings --ignore-case
  \ --no-ignore --hidden --follow --color "always" '

let g:rg_command = g:rg_root_command . ' -g "!.git/**" '

" :Fw  - rg -> (F)zf through fulltext in (w)orking dir, `?` opens preview pane
command! -nargs=* Fw
  \ call fzf#vim#grep(
  \   g:rg_command . ' -- ' . shellescape(<q-args>), 1,
  \   fzf#vim#with_preview('right:50%:hidden', '?'), 0)

" :Fl  - rg -> (F)zf through fulltext in (l)ocal buffer dir, `?` for preview
command! -nargs=* Fl
  \ call fzf#vim#grep(
  \   g:rg_command . ' -- ' . shellescape(<q-args>) . ' ' . shellescape(expand('%:p:h')), 1,
  \   fzf#vim#with_preview('right:50%:hidden', '?'), 0)

" :Docs  - rg through ~/.documentation folder
let g:docs_dir = $HOME . '/.documentation'
command! -nargs=* Docs
  \ call fzf#vim#grep(
  \   g:rg_root_command . ' -- ' . shellescape(<q-args>) . ' ' . shellescape(g:docs_dir), 1,
  \   fzf#vim#with_preview('right:50%:hidden', '?'), 0)
