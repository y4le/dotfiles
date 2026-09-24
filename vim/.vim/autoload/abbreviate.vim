" global map of abbreviations
let g:abbrmap = get(g:, 'abbrmap', {})

" leader for our abbreviations
let g:abbrleader= get(g:, 'abbrleader', ':')

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
  execute printf('cnoreabbrev <expr> %s getcmdtype() ==# '':'' && getcmdline() ==# %s ? %s : %s',
        \ a:trigger, string(g:abbrleader . a:trigger),
        \ string(a:output), string(a:trigger))
  let g:abbrmap[a:trigger] = {'in': a:trigger, 'out': a:output,
        \ 'description': a:description}
endfunction
