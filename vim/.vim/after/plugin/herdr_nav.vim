" inside herdr, replace vim-tmux-navigator's C-h/j/k/l maps with
" vim-herdr-navigation's; editor/vim.vim does nothing outside a herdr pane
let s:plug = get(get(g:, 'plugs', {}), 'vim-herdr-navigation', {})
if !empty(s:plug) && filereadable(s:plug.dir . 'editor/vim.vim')
  execute 'source ' . fnameescape(s:plug.dir . 'editor/vim.vim')
endif
