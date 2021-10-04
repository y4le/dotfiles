
" cycle through diffopts to generate different diffs that might be better
function! CycleDiffopt()
  let diffopts = ['myers', 'minimal', 'patience', 'histogram']
  let currentopt = &diffopt
  for diffopt in diffopts
    if currentopt =~ diffopt
      let currAlgo = diffopts[index(diffopts, diffopt)]
      let nextAlgo = diffopts[(index(diffopts, diffopt) + 1) % len(diffopts)]
      let nextopt = substitute(currentopt, currAlgo, nextAlgo, "")
      let &diffopt = nextopt
      echo "Switched diff algorithm from " . currAlgo . " to " . nextAlgo
      break
    endif
  endfor
endfunction


if has("patch-8.1.0360")
    set diffopt+=internal,algorithm:patience " set better diff algorithm
    nnoremap <leader>Dc :call CycleDiffopt()<cr>
else
  " TOTO: remove once we are confidently on vim > 8.1
  Plug 'chrisbra/vim-diff-enhanced' " better diffs on vim < 8.1
  nnoremap <leader>Dc :EnhancedDiff |" tab complete an algoritm name to switch
endif

nnoremap <leader>Dn ]c|" d(iff) n(ext)
nnoremap <leader>Dp [c|" d(iff) p(revious)
nnoremap <leader>Dg :diffget |" d(iff) g(et)
nnoremap <leader>Do :diffget other<cr>|" d(iff) (get) o(ther)
nnoremap <leader>Db :diffget base<cr>|" d(iff) (get) b(ase)
nnoremap <leader>Du :diffput|" d(iff) (p)u(t)
