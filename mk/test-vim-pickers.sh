#!/bin/sh

set -eu
fail() { echo "check-vim-pickers: $*" >&2; exit 1; }
vim_bin=$(command -v vim)
command -v rg >/dev/null 2>&1 || fail "ripgrep is required"
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/autoload/fzf" "$test_root/bin" "$test_root/home" "$test_root/chosen-dir"
cat > "$test_root/autoload/fzf.vim" <<'EOF'
function! fzf#wrap(name, options) abort
  return a:options
endfunction
function! fzf#run(options) abort
  " Exercise the shell source contract: an explicit empty source is invalid;
  " omitting it lets fzf use the environment at invocation time.
  let g:picker_options = copy(a:options)
  if has_key(a:options, 'source')
    let command = '(' . a:options.source . ')'
    if has_key(a:options, 'dir')
      let command = 'cd ' . shellescape(a:options.dir) . ' && ' . command
    endif
    let g:picker_output = system(command)
  elseif !empty($FZF_DEFAULT_COMMAND)
    let g:picker_output = system($FZF_DEFAULT_COMMAND)
  else
    let g:picker_output = 'default'
  endif
  let g:picker_status = v:shell_error
endfunction
EOF
cat > "$test_root/autoload/fzf/vim.vim" <<'EOF'
function! fzf#vim#with_preview(options, ...) abort
  let g:preview_call = [a:options] + a:000
  return a:options
endfunction
function! fzf#vim#history(...) abort
  let g:history_call = a:000
endfunction
function! fzf#vim#buffers(...) abort
  let g:buffers_call = a:000
endfunction
EOF
cat > "$test_root/fzf-test.vim" <<'EOF'
execute 'set runtimepath^=' . fnameescape($DOTFILES_TEST_ROOT)
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/fzf.vim')
for bang in ['', '!']
  let $FZF_DEFAULT_COMMAND = ''
  execute 'FzfDefault' . bang
  call assert_equal('default', g:picker_output)
  let $FZF_DEFAULT_COMMAND = 'printf late-command'
  execute 'FzfDefault' . bang
  call assert_equal('late-command', g:picker_output)
  call assert_equal(0, g:picker_status)
  call assert_equal(['--multi'], g:picker_options.options)
  call assert_equal(bang ==# '!' ? '100%' : '', get(g:picker_options, 'down', ''))
  call assert_equal(bang ==# '!' ? 'right' : 'right:50%:hidden', g:preview_call[1])
  call assert_equal(bang ==# '!' ? 2 : 3, len(g:preview_call))
endfor
" Evaluate the local directory each time, even when its name needs quoting.
let project = $DOTFILES_TEST_ROOT . '/project'
for directory in ['one space', 'two%#[$]']
  call mkdir(project . '/' . directory, 'p')
  call writefile(['file'], project . '/' . directory . '/choice.txt')
endfor
execute 'lcd ' . fnameescape(project)
for bang in ['', '!']
  execute 'FzfWorkingDir' . bang
  call assert_equal(0, g:picker_status)
  call assert_true(stridx(g:picker_output, 'one space/choice.txt') >= 0)
  call assert_true(stridx(g:picker_output, 'two%#[$]/choice.txt') >= 0)
  for directory in ['one space', 'two%#[$]']
    execute 'edit ' . fnameescape(project . '/' . directory . '/choice.txt')
    execute 'FzfLocalDir' . bang
    call assert_equal(project . '/' . directory, g:picker_options.dir)
    call assert_equal(0, g:picker_status)
    call assert_equal("choice.txt\n", g:picker_output)
    call assert_equal(['--multi'], g:picker_options.options)
    call assert_equal(bang ==# '!' ? '100%' : '', get(g:picker_options, 'down', ''))
  endfor
endfor
execute 'lcd ' . fnameescape($DOTFILES_TEST_ROOT . '/tracked')
for bang in ['', '!']
  execute 'FzfGit' . bang
  call assert_equal(0, g:picker_status)
  call assert_equal("tracked.txt\n", g:picker_output)
endfor
" Recent-file commands remain available without the MRU plugin or its file.
call assert_false(exists('g:MRU_File'))
for command in ['FzfMru', 'Oldfiles']
  for bang in ['', '!']
    execute command . bang
    call assert_equal(bang ==# '!' ? 1 : 0, g:history_call[-1])
  endfor
endfor
" Create a hole in buffer numbers and an unnamed, unlisted scratch buffer.
set hidden
edit first.txt
let first = bufnr('')
edit deleted.txt
let deleted = bufnr('')
edit last.txt
execute 'bwipeout ' . deleted
enew
setlocal buftype=nofile nobuflisted
let scratch = bufnr('')
call assert_false(exists('g:buffergator_mru'))
for bang in ['', '!']
  execute 'Buffs' . bang
  " Let fzf.vim choose and sort listed buffers; do not pass file names.
  call assert_equal(3, len(g:buffers_call))
  call assert_equal('', g:buffers_call[0])
  call assert_equal(bang ==# '!' ? 1 : 0, g:buffers_call[-1])
  call assert_equal('{1}', g:buffers_call[-2].placeholder)
  execute 'AllBuffs' . bang
  call assert_true(index(g:buffers_call[1], first) >= 0)
  call assert_true(index(g:buffers_call[1], scratch) >= 0)
  call assert_equal(-1, index(g:buffers_call[1], deleted))
  call assert_equal(bang ==# '!' ? 1 : 0, g:buffers_call[-1])
endfor
" fzf.vim history abbreviates home paths; quickfix needs absolute filenames
" without expanding literal percent, hash, or wildcard characters.
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/autoload/quickfix.vim')
let $QF_LITERAL = 'expanded'
let history_file = $HOME . '/history%#[$QF_LITERAL].txt'
call writefile(['history'], history_file)
call quickfix#BuildQuickfix(['~/history%#[$QF_LITERAL].txt'])
call assert_equal(history_file, getbufinfo(getqflist()[0].bufnr)[0].name)
call assert_equal(history_file, expand('%:p'))
if !empty(v:errors) | call writefile(v:errors, $DOTFILES_RESULT) | cquit | endif
qa!
EOF
mkdir -p "$test_root/tracked"
git -c core.hooksPath=/dev/null init -q "$test_root/tracked"
printf 'tracked\n' > "$test_root/tracked/tracked.txt"
printf 'untracked\n' > "$test_root/tracked/untracked.txt"
git -C "$test_root/tracked" add tracked.txt

echo "check-vim-pickers: file and buffer pickers work without MRU or Buffergator"
env -i HOME="$test_root/home" PATH="$PATH" LC_ALL=C \
  DOTFILES_REPO="$repo" DOTFILES_TEST_ROOT="$test_root" DOTFILES_RESULT="$test_root/result" \
  "$vim_bin" -Nu NONE -i NONE -n -es -S "$test_root/fzf-test.vim" || {
    [ ! -f "$test_root/result" ] || cat "$test_root/result" >&2
    fail "fzf source selection failed";
  }

cat > "$test_root/bin/yazi" <<'EOF'
#!/bin/sh
cwd=$2
chooser=$4
while [ ! -f "$DOTFILES_RELEASE" ]; do sleep 0.02; done
printf '%s\n' "$DOTFILES_CHOSEN_DIR" > "$cwd"
printf '%s\n' "$DOTFILES_CHOSEN_DIR/chosen.txt" > "$chooser"
EOF
chmod +x "$test_root/bin/yazi"
printf 'chosen\n' > "$test_root/chosen-dir/chosen.txt"
cat > "$test_root/yazi-test.vim" <<'EOF'
if !has('terminal')
  if !empty($CI) | cquit | endif
  call writefile(['skip'], $DOTFILES_TEST_ROOT . '/no-terminal')
  qa!
endif
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/yazi.vim')
for close_origin in [0, 1]
  call delete($DOTFILES_RELEASE)
  only
  enew
  let fallback = win_getid()
  topleft vnew
  setlocal buftype=nofile
  call win_gotoid(fallback)
  split
  let origin = win_getid()
  execute 'lcd ' . fnameescape($DOTFILES_TEST_ROOT)
  Yazi
  stopinsert
  if close_origin
    call win_gotoid(origin)
    close
  endif
  call writefile(['go'], $DOTFILES_RELEASE)
  let deadline = reltime()
  while expand('%:p') !=# $DOTFILES_CHOSEN_DIR . '/chosen.txt' && reltimefloat(reltime(deadline)) < 10
    sleep 20m
  endwhile
  call assert_equal(close_origin ? fallback : origin, win_getid())
  call assert_equal($DOTFILES_CHOSEN_DIR . '/chosen.txt', expand('%:p'))
  call assert_equal($DOTFILES_CHOSEN_DIR, getcwd())
  call assert_equal('', &buftype)
endfor
if !empty(v:errors) | call writefile(v:errors, $DOTFILES_RESULT) | cquit | endif
qa!
EOF
echo "check-vim-pickers: Yazi returns to the original or surviving window"
env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" LC_ALL=C TERM=dumb CI="${CI:-}" \
  DOTFILES_REPO="$repo" DOTFILES_TEST_ROOT="$test_root" DOTFILES_RESULT="$test_root/result" \
  DOTFILES_RELEASE="$test_root/release" DOTFILES_CHOSEN_DIR="$test_root/chosen-dir" \
  "$vim_bin" -Nu NONE -i NONE -n -es -S "$test_root/yazi-test.vim" || {
    [ ! -f "$test_root/result" ] || cat "$test_root/result" >&2
    fail "Yazi window selection failed";
  }
[ ! -f "$test_root/no-terminal" ] || echo "check-vim-pickers: terminal feature unavailable; Yazi cases skipped"
echo "check-vim-pickers: ok"
