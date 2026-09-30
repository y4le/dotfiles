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

echo "check-vim: command-line abbreviations"
env DOTFILES_REPO="$repo" vim -Nu NONE -i NONE -n -es \
  -S "$repo/mk/test-vim-abbrev.vim" || fail "Vim abbreviations changed commands or word motions"

echo "check-vim: movement and regex defaults"
env DOTFILES_REPO="$repo" DOTFILES_TEST_ROOT="$test_root" \
  vim -Nu NONE -i NONE -n -es -S "$repo/mk/test-vim-defaults.vim" || {
    [ ! -f "$test_root/errors" ] || cat "$test_root/errors" >&2
    fail "Vim movement or regex defaults failed"
  }

echo "check-vim: persistent recent-file history"
env DOTFILES_REPO="$repo" DOTFILES_TEST_ROOT="$test_root" \
  vim -Nu NONE -i NONE -n -es -S "$repo/mk/test-vim-history.vim" || {
    [ ! -f "$test_root/errors" ] || cat "$test_root/errors" >&2
    fail "Vim recent-file history depth failed"
  }

echo "check-vim: plugin restore verification"
mkdir -p "$test_root/installed-plugin"
mkdir -p "$test_root/installed-plugin/.git"
DOTFILES_TEST_PLUGIN_DIR="$test_root/installed-plugin" \
  vim -Nu NONE -i NONE -n -es \
    -c 'let g:plugs = {"fixture": {"dir": $DOTFILES_TEST_PLUGIN_DIR, "uri": "https://example.invalid/fixture.git"}}' \
    -S "$repo/mk/verify-vim-plugins.vim" -c 'qa!' || \
  fail "installed Vim plugin was rejected"
DOTFILES_TEST_PLUGIN_DIR="$test_root/missing-plugin" \
  vim -Nu NONE -i NONE -n -es \
    -c 'let g:plugs = {"fixture": {"dir": $DOTFILES_TEST_PLUGIN_DIR, "uri": "https://example.invalid/fixture.git"}}' \
    -S "$repo/mk/verify-vim-plugins.vim" -c 'qa!' \
    > "$test_root/missing-plugin.out" 2>&1 && \
  fail "missing Vim plugin was accepted"

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
    XDG_STATE_HOME="$runtime_home/xdg-state" \
    LC_ALL=C HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 DOTFILES_NETWORK_LOG="$network_log" \
    DOTFILES_VIM_MESSAGES="$messages" DOTFILES_VIM_STATE="$state" \
    vim -Nu "$runtime_home/.vimrc" -n -es \
      -c 'call writefile(split(execute("messages"), "\n"), $DOTFILES_VIM_MESSAGES)' \
      -c 'call writefile([exists("g:airline#extensions#tabline#formatter"), exists(":FzfMru"), maparg("\<Space>Fm", "n"), maparg("\<Space>Fpm", "n"), get(g:, "colors_name", ""), $VIMSTATE, &viminfofile, &undodir, &directory, &backupdir, &viewdir, get(g:, "MRU_File", ""), string(get(g:, "signify_skip", {}))], $DOTFILES_VIM_STATE)' \
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
vim_state=$runtime_home/xdg-state/vim
[ "$(sed -n '6p' "$state")" = "$vim_state" ] || \
  fail "Vim ignored XDG_STATE_HOME"
[ "$(sed -n '7p' "$state")" = "$vim_state/viminfo" ] || \
  fail "Vim used the wrong viminfo path"
[ "$(sed -n '8p' "$state")" = "$vim_state/undo//" ] || \
  fail "Vim used the wrong undo path"
[ "$(sed -n '9p' "$state")" = "$vim_state/swap//" ] || \
  fail "Vim used the wrong swap path"
[ "$(sed -n '10p' "$state")" = "$vim_state/backup//" ] || \
  fail "Vim used the wrong backup path"
[ "$(sed -n '11p' "$state")" = "$vim_state/view" ] || \
  fail "Vim used the wrong view path"
for state_dir in backup sessions swap undo view; do
  [ -d "$vim_state/$state_dir" ] || fail "Vim did not create $state_dir state"
done
[ -f "$vim_state/viminfo" ] || fail "Vim did not write viminfo state"

relative_state_output=$test_root/relative-state.out
if ! env -i HOME="$runtime_home" PATH="$runtime_bin:/usr/local/bin:/usr/bin:/bin" \
  XDG_STATE_HOME=relative LC_ALL=C DOTFILES_NETWORK_LOG="$network_log" \
  DOTFILES_RELATIVE_STATE="$relative_state_output" \
  vim -Nu "$runtime_home/.vimrc" -i NONE -n -es \
    -c 'call writefile([$VIMSTATE], $DOTFILES_RELATIVE_STATE)' \
    -c 'qa!' > /dev/null 2> "$runtime_stderr"; then
  fail "Vim failed with a relative XDG_STATE_HOME"
fi
[ "$(cat "$relative_state_output")" = "$runtime_home/.local/state/vim" ] || \
  fail "Vim accepted a relative XDG_STATE_HOME"

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
[ -z "$(sed -n '12p' "$state")" ] || fail "disabled MRU plugin retained a state path"
[ "$(sed -n '13p' "$state")" = "{'vcs': {'allow': ['git']}}" ] || fail "Signify is not limited to Git"
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

installed_plug=${DOTFILES_TEST_VIM_PLUG:-${HOME:-}/.vim/autoload/plug.vim}
if [ -n "${HOME:-}" ] && \
  DOTFILES_PINS_FILE="$repo/setup/pins/downloads.txt" \
    sh "$repo/mk/pinned.sh" status vim-plug "$installed_plug" >/dev/null 2>&1; then
  cp "$installed_plug" "$runtime_home/.vim/autoload/plug.vim"
  rm -f "$runtime_home/.vim/colors/sublimemonokai.vim"
  mkdir -p "$runtime_home/.local/share/vim/plugged"
  if ! run_startup; then
    print_startup_failure
    fail "startup with pinned vim-plug and no plugins failed"
  fi
  if grep -F "plug.vim not found" "$messages" >/dev/null; then
    fail "startup with pinned vim-plug reported it missing"
  fi
  assert_clean_startup "startup with pinned vim-plug"

  echo "check-vim: commit pin changes update existing checkouts"
  fixture_git() {
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
      git -c core.hooksPath=/dev/null -c commit.gpgsign=false \
        -c user.name=test -c user.email=test@example.invalid "$@"
  }
  pin_source=$test_root/pin-source
  fixture_git init -q "$pin_source"
  printf 'first\n' > "$pin_source/plugin.txt"
  fixture_git -C "$pin_source" add plugin.txt
  fixture_git -C "$pin_source" commit -qm first
  first_pin=$(fixture_git -C "$pin_source" rev-parse HEAD)
  printf 'second\n' > "$pin_source/plugin.txt"
  fixture_git -C "$pin_source" commit -qam second
  second_pin=$(fixture_git -C "$pin_source" rev-parse HEAD)
  plugged=$test_root/pin-plugins
  mkdir -p "$plugged"
  for plugin in pinned branch; do
    fixture_git clone -q "$pin_source" "$plugged/$plugin"
    fixture_git -C "$plugged/$plugin" checkout -q --detach "$first_pin"
  done
  cat > "$test_root/restore-pins.vim" <<'EOF'
execute 'source ' . fnameescape($DOTFILES_TEST_VIM_PLUG)
call plug#begin($DOTFILES_TEST_PLUGGED)
call plug#('file://' . $DOTFILES_TEST_REMOTE, {'as': 'pinned', 'commit': $DOTFILES_TEST_PIN})
call plug#('file://' . $DOTFILES_TEST_REMOTE, {'as': 'branch'})
call plug#end()
PlugInstall --sync
execute 'source ' . fnameescape($DOTFILES_TEST_REPO . '/mk/restore-vim-pins.vim')
execute 'source ' . fnameescape($DOTFILES_TEST_REPO . '/mk/verify-vim-plugins.vim')
qa!
EOF
  HOME="$runtime_home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    DOTFILES_TEST_VIM_PLUG="$installed_plug" DOTFILES_TEST_PLUGGED="$plugged" \
    DOTFILES_TEST_REMOTE="$pin_source" DOTFILES_TEST_PIN="$second_pin" DOTFILES_TEST_REPO="$repo" \
    vim -Nu NONE -i NONE -n -es -S "$test_root/restore-pins.vim" || fail "Vim pin restore failed"
  [ "$(fixture_git -C "$plugged/pinned" rev-parse HEAD)" = "$second_pin" ] || fail "Vim retained its old commit pin"
  [ "$(fixture_git -C "$plugged/branch" rev-parse HEAD)" = "$first_pin" ] || fail "restore updated an unpinned branch plugin"
  mv "$pin_source" "$pin_source.offline"
  HOME="$runtime_home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    DOTFILES_TEST_VIM_PLUG="$installed_plug" DOTFILES_TEST_PLUGGED="$plugged" \
    DOTFILES_TEST_REMOTE="$pin_source" DOTFILES_TEST_PIN="$second_pin" DOTFILES_TEST_REPO="$repo" \
    vim -Nu NONE -i NONE -n -es -S "$test_root/restore-pins.vim" || fail "on-pin Vim restore contacted its unavailable remote"
  DOTFILES_TEST_PLUGIN_DIR="$plugged/pinned" DOTFILES_TEST_PIN="$first_pin" \
    vim -Nu NONE -i NONE -n -es \
    -c 'let g:plugs = {"pinned": {"dir": $DOTFILES_TEST_PLUGIN_DIR, "uri": "fixture", "commit": $DOTFILES_TEST_PIN}}' \
    -S "$repo/mk/verify-vim-plugins.vim" -c 'qa!' > "$test_root/wrong-pin.out" 2>&1 && \
    fail "Vim verifier accepted an off-pin checkout"
else
  [ -z "${CI:-}" ] || fail "pinned vim-plug fixture is required in CI"
  echo "check-vim: pinned vim-plug startup fixture unavailable; skipping"
fi

DOTFILES_TEST_VIM_PLUG="$installed_plug" sh "$repo/mk/test-vim-filetypes.sh" || fail "Vim filetype checks failed"
sh "$repo/mk/test-vim-pickers.sh" || fail "Vim picker checks failed"

echo "check-vim: ok"
