runtime! ftplugin/markdown.vim

vnoremap Sa :sort<cr>|" sorts selection alphabetically
vnoremap Ss :'<,'>sort /[^\[]\+/<cr>|" sort selection by first [tag] in line
