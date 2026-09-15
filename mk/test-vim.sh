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

config=$(pwd -P)/vim/.vim/plugin/wiki.vim

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

echo "check-vim: ok"
