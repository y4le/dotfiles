#!/bin/sh

set -eu
fail() { echo "check-vim-paths: $*" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || fail "ripgrep is required"
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/autoload/fzf" "$test_root/home space%#\$"
cat > "$test_root/autoload/fzf.vim" <<'EOF'
function! fzf#run(options) abort
  let g:session_picker = a:options
endfunction
EOF
cat > "$test_root/autoload/fzf/vim.vim" <<'EOF'
function! fzf#vim#with_preview(...) abort
  return {}
endfunction
function! fzf#vim#grep(command, ...) abort
  let g:search_output = system(a:command)
  let g:search_status = v:shell_error
endfunction
EOF
cat > "$test_root/paths.vim" <<'EOF'
execute 'set runtimepath^=' . fnameescape($DOTFILES_TEST_ROOT)
execute 'set runtimepath+=' . fnameescape($DOTFILES_REPO . '/vim/.vim')
let root = $DOTFILES_TEST_ROOT . "/work space%#[$]'"
call mkdir(root . '/scope space', 'p')
call mkdir(root . '/.git', 'p')
call mkdir($HOME . '/.documentation', 'p')
let needle = "-needle ' $ % # [x]"
call writefile([needle], root . '/scope space/inside.txt')
call writefile([needle], root . '/outside.txt')
call writefile([needle], root . '/.git/private.txt')
call writefile([needle], $HOME . '/.documentation/doc.txt')
execute 'cd ' . fnameescape(root)
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/search.vim')
execute 'Fw ' . needle
call assert_equal(0, g:search_status, 'Fw failed to search a leading-dash literal')
call assert_true(stridx(g:search_output, 'inside.txt') >= 0)
call assert_true(stridx(g:search_output, 'outside.txt') >= 0)
call assert_equal(-1, stridx(g:search_output, 'private.txt'), 'Fw searched .git')
execute 'edit ' . fnameescape(root . '/scope space/inside.txt')
execute 'Fl ' . needle
call assert_equal(0, g:search_status, 'Fl failed in a path with spaces')
call assert_true(stridx(g:search_output, 'inside.txt') >= 0)
call assert_equal(-1, stridx(g:search_output, 'outside.txt'), 'Fl escaped its scope')
execute 'Docs ' . needle
call assert_equal(0, g:search_status, 'Docs failed in a home path with spaces')
call assert_true(stridx(g:search_output, 'doc.txt') >= 0)

let $VIMSTATE = root . "/state space%#[$]'"
call mkdir($VIMSTATE . '/sessions/subdirectory', 'p')
call writefile(['hidden'], $VIMSTATE . '/sessions/.hidden')
let session_name = "saved space%#[$]' session.vim"
call writefile(['let g:session_loaded = 1'], $VIMSTATE . '/sessions/' . session_name)
execute 'source ' . fnameescape($DOTFILES_REPO . '/vim/.vim/plugin/sessions.vim')
Sessions
call assert_equal([session_name], g:session_picker.source, 'Sessions changed names or included a directory')
call call(g:session_picker.sink, [session_name])
call assert_equal(1, get(g:, 'session_loaded', 0), 'Sessions sourced the wrong path')
call writefile(['let g:session_abbreviation_loaded = 1'], $VIMSTATE . '/sessions/load.vim')
call feedkeys(":sl/load.vim\<CR>", 'xt')
call assert_equal(1, get(g:, 'session_abbreviation_loaded', 0), ':sl did not escape the state path')
call feedkeys(":ss/save.vim\<CR>", 'xt')
call assert_true(filereadable($VIMSTATE . '/sessions/save.vim'), ':ss did not escape the state path')
Sessions
call assert_equal(3, len(g:session_picker.source), 'Sessions froze its directory listing')

" File navigation must preserve literal percent and hash characters.
only
enew
let origin = win_getid()
let filename = 'target%#$.txt'
call writefile(['target'], root . '/' . filename)
call setline(1, filename)
normal! gg0
vnew
let destination = win_getid()
call win_gotoid(origin)
for Navigate in [function('nav#OpenInPrevSplit'), function('nav#OpenInNextSplit')]
  call Navigate()
  call assert_equal(origin, win_getid(), 'navigation did not return to its window')
  call assert_equal(root . '/' . filename, getbufinfo(winbufnr(destination))[0].name, 'navigation expanded filename characters')
endfor
let $NAV_ROOT = root
call setline(1, '$NAV_ROOT/' . filename)
normal! gg0
for Navigate in [function('nav#OpenInPrevSplit'), function('nav#OpenInNextSplit')]
  call Navigate()
  call assert_equal(root . '/' . filename, getbufinfo(winbufnr(destination))[0].name, 'navigation did not expand the environment variable')
endfor
if !empty(v:errors) | call writefile(v:errors, $DOTFILES_RESULT) | cquit | endif
qa!
EOF
echo "check-vim-paths: literal search terms, session paths, and split navigation"
env -i HOME="$test_root/home space%#\$" PATH="$PATH" LC_ALL=C \
  DOTFILES_REPO="$repo" DOTFILES_TEST_ROOT="$test_root" DOTFILES_RESULT="$test_root/result" \
  vim -Nu NONE -i NONE -n -es -S "$test_root/paths.vim" || {
    [ ! -f "$test_root/result" ] || cat "$test_root/result" >&2
    fail "literal search or filename handling failed";
  }
echo "check-vim-paths: ok"
