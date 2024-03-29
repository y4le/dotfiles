
" RESIZE MODE

" depends on vim-submode, e.g.
" Plug 'kana/vim-submode' " let us define like i3 modes
" nmap <C-w>r <Nop>
"
" call submode#enter_with('resize', 'n', '', '<C-w>r')
" " call submode#leave_with('resize', 'n', '', '<Esc>')



" " A message will appear in the message line when you're in a submode
" " and stay there until the mode has existed.
" let g:submode_always_show_submode = 1
"
" " We're taking over the default <C-w> setting. Don't worry we'll do
" " our best to put back the default functionality.
" call submode#enter_with('window', 'n', '', '<C-w>')
"
" " Note: <C-c> will also get you out to the mode without this mapping.
" " Note: <C-[> also behaves as <ESC>
" call submode#leave_with('window', 'n', '', '<ESC>')
"
" " Go through every letter
" for key in ['a','b','c','d','e','f','g','h','i','j','k','l','m',
" \           'n','o','p','q','r','s','t','u','v','w','x','y','z']
"   " maps lowercase, uppercase and <C-key>
"   call submode#map('window', 'n', '', key, '<C-w>' . key)
"   call submode#map('window', 'n', '', toupper(key), '<C-w>' . toupper(key))
"   call submode#map('window', 'n', '', '<C-' . key . '>', '<C-w>' . '<C-'.key . '>')
" endfor
" " Go through symbols. Sadly, '|', not supported in submode plugin.
" for key in ['=','_','+','-','<','>']
"   call submode#map('window', 'n', '', key, '<C-w>' . key)
" endfor
"
"
"
" " I don't like <C-w>q, <C-w>c won't exit Vim when it's the last window.
" call submode#map('window', 'n', '', 'q', '<C-w>c')
" call submode#map('window', 'n', '', '<C-q>', '<C-w>c')
"
" " <lowercase-pipe> sets the width to 80 columns, pipe (<S-\>) by default
" " maximizes the width.
" call submode#map('window', 'n', '', '\', ':vertical resize 80<CR>')
"
" " Resize faster
" call submode#map('window', 'n', '', '+', '3<C-w>+')
" call submode#map('window', 'n', '', '-', '3<C-w>-')
" call submode#map('window', 'n', '', '<', '10<C-w><')
" call submode#map('window', 'n', '', '>', '10<C-w>>')
