let s:profile_file='/tmp/vim_profile.log'

function! profiler#start()
  execute ':profile start ' . s:profile_file
  profile func *
  profile file *
endfunction

function! profiler#end()
  profile pause
  execute ':tabedit ' . s:profile_file
endfunction
