#!/bin/sh

set -eu
fail() { echo "check-vim-pickers: $*" >&2; exit 1; }
vim_bin=$(command -v vim)
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
  if has_key(a:options, 'source')
    let g:picker_output = system('(' . a:options.source . ')')
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
  return a:options
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
endfor
if !empty(v:errors) | call writefile(v:errors, $DOTFILES_RESULT) | cquit | endif
qa!
EOF
echo "check-vim-pickers: fzf command uses the current environment"
env -i HOME="$test_root/home" PATH=/usr/bin:/bin LC_ALL=C \
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
