" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

nmap <buffer> <LeftMouse><LeftMouse> <Plug>(w3m-click)
nmap <buffer> <CR>                   <Plug>(w3m-click)
nmap <buffer> <S-CR>                 <Plug>(w3m-shift-click)
nmap <buffer> <C-S-CR>               <Plug>(w3m-shift-ctrl-click)
nmap <buffer> <C-n>                  <Plug>(w3m-next-link)
nmap <buffer> <C-p>                  <Plug>(w3m-prev-link)
nmap <buffer> <BS>                   <Plug>(w3m-back)
nmap <buffer> <S-BS>                 <Plug>(w3m-forward)
nmap <buffer> s                      <Plug>(w3m-toggle-syntax)
nmap <buffer> c                      <Plug>(w3m-toggle-use-cookie)
nmap <buffer> =                      <Plug>(w3m-show-link)
nmap <buffer> /                      <Plug>(w3m-search-start)
nmap <buffer> *                      *<Plug>(w3m-search-end)
nmap <buffer> #                      #<Plug>(w3m-search-end)
nmap <buffer> <C-a>                  <Plug>(w3m-address-bar)
nmap <buffer> f                      <Plug>(w3m-hit-a-hint)

