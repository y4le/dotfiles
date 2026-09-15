#!/bin/sh

set -u

fail() {
  echo "check-vim: $*" >&2
  exit 1
}

if ! command -v vim >/dev/null 2>&1; then
  echo "check-vim: vim not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-vim: skipping outside CI"
  exit 0
fi

test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
config=$repo/vim/.vim/plugin/wiki.vim

run_case() {
  label=$1
  test_home=$2
  env_root=$3
  global_root=$4
  expected=$5
  output=$test_root/$label.out

  mkdir -p "$test_home"
  if ! env -i HOME="$test_home" PATH="$PATH" LC_ALL=C \
    VIMWIKI_ROOT="$env_root" DOTFILES_WIKI_CONFIG="$config" \
    DOTFILES_WIKI_OUTPUT="$output" DOTFILES_WIKI_GLOBAL="$global_root" \
    vim -Nu NONE -n -es \
      -c "if !empty(\$DOTFILES_WIKI_GLOBAL) | let g:vimwiki_root = \$DOTFILES_WIKI_GLOBAL | endif" \
      -c "execute 'source ' . fnameescape(\$DOTFILES_WIKI_CONFIG)" \
      -c "call writefile([g:vimwiki_list[0].path, g:vimwiki_list[1].path], \$DOTFILES_WIKI_OUTPUT)" \
      -c 'qa!'; then
    fail "$label could not source wiki.vim"
  fi

  expected_work=$expected/work/wiki
  expected_personal=$expected/personal/wiki
  [ "$(sed -n '1p' "$output")" = "$expected_work" ] || \
    fail "$label selected the wrong work wiki root"
  [ "$(sed -n '2p' "$output")" = "$expected_personal" ] || \
    fail "$label selected the wrong personal wiki root"
}

echo "check-vim: VimWiki root precedence"
run_case fallback "$test_root/home" '' '' "$test_root/home/vimwiki"
run_case environment "$test_root/home" "$test_root/environment wiki" '' \
  "$test_root/environment wiki"
run_case literal-dollar "$test_root/home" "$test_root/price\$5" '' \
  "$test_root/price\$5"
run_case global "$test_root/home" "$test_root/environment wiki" \
  "$test_root/global wiki" "$test_root/global wiki"

if ! command -v stow >/dev/null 2>&1; then
  echo "check-vim: stow not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-vim: skipping runtime startup outside CI"
  echo "check-vim: ok"
  exit 0
fi

echo "check-vim: offline startup"
runtime_home=$test_root/runtime-home
runtime_bin=$test_root/runtime-bin
runtime_package=$test_root/package/vim
network_log=$test_root/network.log
messages=$test_root/messages
state=$test_root/state
runtime_stderr=$test_root/runtime.stderr
mkdir -p "$runtime_home" "$runtime_bin" "$runtime_package"
tracked_vim_files=$(git -c core.quotePath=false -C "$repo" ls-files 'vim/*') || \
  fail "could not enumerate tracked Vim files"
while IFS= read -r tracked; do
  [ -n "$tracked" ] || continue
  relative=${tracked#vim/}
  mkdir -p "$runtime_package/$(dirname "$relative")"
  cp "$repo/$tracked" "$runtime_package/$relative" || \
    fail "could not copy tracked Vim file: $tracked"
done <<EOF
$tracked_vim_files
EOF
rm -f "$runtime_package/.vim/autoload/plug.vim"
stow -R --no-folding -d "$test_root/package" -t "$runtime_home" vim

for command_name in curl wget git; do
  # This single-quoted line is the body of the generated command stub.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s %s\n" "$0" "$*" >> "$DOTFILES_NETWORK_LOG"' \
    'exit 97' > "$runtime_bin/$command_name"
  chmod +x "$runtime_bin/$command_name"
done

run_startup() {
  : > "$network_log"
  : > "$messages"
  : > "$state"
  : > "$runtime_stderr"
  # These expressions are intentionally evaluated by Vim, not this shell.
  # shellcheck disable=SC2016
  env -i HOME="$runtime_home" PATH="$runtime_bin:/usr/local/bin:/usr/bin:/bin" \
    LC_ALL=C HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 DOTFILES_NETWORK_LOG="$network_log" \
    DOTFILES_VIM_MESSAGES="$messages" DOTFILES_VIM_STATE="$state" \
    vim -Nu "$runtime_home/.vimrc" -i NONE -n -es \
      -c 'call writefile(split(execute("messages"), "\n"), $DOTFILES_VIM_MESSAGES)' \
      -c 'call writefile([exists("g:MRU_File"), exists(":FzfMru"), maparg("\<Space>Fm", "n"), maparg("\<Space>Fpm", "n"), get(g:, "colors_name", "")], $DOTFILES_VIM_STATE)' \
      -c 'qa!' > /dev/null 2> "$runtime_stderr"
}

print_startup_failure() {
  sed 's/^/check-vim: vim: /' "$messages" "$runtime_stderr" >&2
}

assert_clean_startup() {
  label=$1
  if grep -Eq 'E[0-9]+:' "$messages" "$runtime_stderr"; then
    sed 's/^/check-vim: vim: /' "$messages" "$runtime_stderr" >&2
    fail "$label reported a Vim error"
  fi
  [ ! -s "$network_log" ] || fail "$label accessed the network"
}

if ! run_startup; then
  print_startup_failure
  fail "startup without vim-plug failed"
fi
hint_count=$(grep -Fc "plug.vim not found - run 'make vim-plugins'" "$messages" || true)
[ "$hint_count" -eq 1 ] || fail "startup without vim-plug did not report one recovery hint"
assert_clean_startup "startup without vim-plug"

cat > "$runtime_home/.vim/autoload/plug.vim" <<'EOF'
function! plug#begin(...) abort
  command! -nargs=+ -bar Plug call plug#(<args>)
endfunction
function! plug#(repo, ...) abort
endfunction
function! plug#end() abort
  delcommand Plug
endfunction
EOF
if ! run_startup; then
  print_startup_failure
  fail "startup with stub vim-plug and no plugins failed"
fi
if grep -F "plug.vim not found" "$messages" >/dev/null; then
  fail "startup with stub vim-plug reported it missing"
fi
[ "$(sed -n '1p' "$state")" = 1 ] || fail "stub vim-plug did not finish plugin config"
[ "$(sed -n '2p' "$state")" = 2 ] || fail "FzfMru was not defined"
[ "$(sed -n '3p' "$state")" = ':FzfMru<CR>' ] || fail "FzfMru mapping was not defined"
[ "$(sed -n '4p' "$state")" = ':FzfMru!<CR>' ] || fail "FzfMru preview mapping was not defined"
assert_clean_startup "startup with stub vim-plug"

mkdir -p "$runtime_home/.vim/colors"
printf '%s\n' "let g:colors_name = 'sublimemonokai'" \
  > "$runtime_home/.vim/colors/sublimemonokai.vim"
if ! run_startup; then
  print_startup_failure
  fail "startup with an available colorscheme failed"
fi
[ "$(sed -n '5p' "$state")" = sublimemonokai ] || \
  fail "available colorscheme was not loaded"
assert_clean_startup "startup with an available colorscheme"

echo "check-vim: ok"
