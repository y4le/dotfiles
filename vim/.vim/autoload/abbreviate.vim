" global map of abbreviations
let g:abbrmap = get(g:, 'abbrmap', {})

" leader for our abbreviations
let g:abbrleader= get(g:, 'abbrleader', ':')

" make sure vim recognizes leader as a token when processing abbreviations
execute 'set iskeyword +=' . g:abbrleader

" Abbr - takes options dict
"   in: abbreviation trigger
"   out: abbreviation output
"   type: abbr command, e.g. cnoreabbr/noreabbr/ab
"   prefix: leader key for abbreviation, defaults to g:abbrleader
"   description: text description of purpose of abbr
function! abbreviate#Abbr(options)
  let options = get(a:, 'options', {})

  " required
  let in = options['in']
  let out = options['out']

  " optional
  let type = get(options, 'type', 'cnoreabbr')
  let prefix = get(options, 'prefix', g:abbrleader)
  let description = get(options, 'description', '')

  " call abbreviate#Abbr({'in': 'foo', 'out': 'foobar', 'desc': 'baz'})
  " ->
  " `cnoreabbr :foo foobar|"baz
  execute type prefix . in out . '|"' . description
  let g:abbrmap[in] = options
endfunction

function! abbreviate#Cnoreabbr(trigger, output, description)
  call abbreviate#Abbr({
        \  'in': a:trigger,
        \  'out': a:output,
        \  'type': 'cnoreabbr',
        \  'prefix': g:abbrleader,
        \  'description': a:description
        \})
endfunction



let g:abbreviation_desc_joiner = ' | '

function! s:showSink(abbr_string)
  let [key, desc] = split(a:abbr_string, g:abbreviation_desc_joiner)
  let abbr = get(g:abbrmap, trim(key), {
        \'in': '', 'out': '',
        \'description': 'abbreviation not found in g:abbrmap'})
  echom a:abbr_string
  echom key
  echom desc
  echom abbr
endfunction

cmap <C-j> call abbreviate#fzf('c')<cr>

function! abbreviate#fzf(mode, ...)
  let s:map_gv  = a:mode == 'x' ? 'gv' : ''
  let s:map_cnt = v:count == 0 ? '' : v:count
  let s:map_reg = empty(v:register) ? '' : ('"'.v:register)
  let s:map_op  = a:mode == 'o' ? v:operator : ''

  redir => cout
  silent execute 'verbose' a:mode.'abbr'
  redir END

  let list = []
  let curr = ''
  for line in split(cout, "\n")
    if line =~ "^\t"
      let [name; desc_list] = split(curr)
      let formatted = printf('%s%s%s', name, g:abbreviation_desc_joiner, join(desc_list))
      echom formatted
      call add(list, formatted)
      " call add(list, printf('%s %s', curr, src))
      let curr = ''
    else
      let curr = line[3:]
    endif
  endfor

  if !empty(curr)
    call add(list, curr)
  endif

  let aligned = s:align_pairs(list)
  let sorted  = sort(aligned)
  let pcolor  = a:mode == 'x' ? 9 : a:mode == 'o' ? 10 : 12

  call fzf#run({
  \ 'source':  sorted,
  \ 'sink':    function('s:showSink'),
  \ 'options': '--prompt "Abbr ('.a:mode.')> " --ansi --no-hscroll --nth 1,.. --color prompt:'.pcolor})
endfunction

function! s:align_pairs(list)
  let maxlen = 0
  let pairs = []
  for elem in a:list
    let match = matchlist(elem, '^\(\S*\)\s*\(.*\)$')
    let [_, k, v] = match[0:2]
    let maxlen = max([maxlen, len(k)])
    call add(pairs, [k, substitute(v, '^\*\?[@ ]\?', '', '')])
  endfor
  let maxlen = min([maxlen, 35])
  return map(pairs, "printf('%-'.maxlen.'s', v:val[0]).' '.v:val[1]")
endfunction

