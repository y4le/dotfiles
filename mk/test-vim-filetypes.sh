#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
fail() { echo "check-vim-filetypes: $*" >&2; exit 1; }
vim_bin=$(command -v vim)
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
test_home=$test_root/home
mkdir -p "$test_home"
git -c core.quotePath=false -C "$repo" ls-files 'vim/*' > "$test_root/files"
while IFS= read -r file; do
  relative=${file#vim/}
  mkdir -p "$test_home/$(dirname "$relative")"
  cp "$repo/$file" "$test_home/$relative"
done < "$test_root/files"
rm -f "$test_home/.vim/autoload/plug.vim"

cat > "$test_root/verify.vim" <<'EOF'
function! AuditFiletype() abort
  let errors = filter(split(execute('messages'), "\n"), 'v:val =~# "E[0-9]\\+:"')
  if &filetype !=# $DOTFILES_EXPECTED_FT || &syntax !=# $DOTFILES_EXPECTED_SYNTAX || !empty(errors)
    call writefile([expand('%:p'), &filetype, &syntax] + errors, $DOTFILES_VIM_RESULT)
    cquit
  endif
  if expand('%:p') !=# $DOTFILES_VIM_FILE
    call writefile(['startup changed the current buffer'], $DOTFILES_VIM_RESULT)
    cquit
  endif
  qa!
endfunction
autocmd VimEnter * call AuditFiletype()
EOF

run_case() {
  extension=$1
  filetype=$2
  syntax=$3
  file=${4:-$test_root/sample.$extension}
  mkdir -p "$(dirname "$file")"
  printf '# Heading\ntext\n' > "$file"
  if ! env -i HOME="$test_home" PATH=/usr/bin:/bin TERM=dumb LC_ALL=C \
    DOTFILES_EXPECTED_FT="$filetype" DOTFILES_EXPECTED_SYNTAX="$syntax" \
    DOTFILES_VIM_FILE="$file" DOTFILES_VIM_RESULT="$test_root/result" \
    "$vim_bin" -Nu "$test_home/.vimrc" -i NONE -n -es "$file" -S "$test_root/verify.vim" \
    > "$test_root/vim.out" 2>&1; then
    cat "$test_root/vim.out" >&2
    [ ! -f "$test_root/result" ] || cat "$test_root/result" >&2
    fail "named .$extension startup failed"
  fi
}

echo "check-vim-filetypes: named files without restored plugins"
run_case md markdown markdown
run_case wiki markdown markdown
run_case book book vimwiki

vimwiki=${DOTFILES_TEST_VIMWIKI:-$HOME/.local/share/vim/plugged/vimwiki}
plug=${DOTFILES_TEST_VIM_PLUG:-$HOME/.vim/autoload/plug.vim}
if [ ! -f "$vimwiki/plugin/vimwiki.vim" ] || [ ! -f "$plug" ]; then
  [ -z "${CI:-}" ] || fail "real VimWiki/vim-plug fixtures required in CI"
  echo "check-vim-filetypes: real plugins unavailable; skipping restored cases"
  exit 0
fi
mkdir -p "$test_home/.local/share/vim/plugged"
cp "$plug" "$test_home/.vim/autoload/plug.vim"
ln -s "$vimwiki" "$test_home/.local/share/vim/plugged/vimwiki"
echo "check-vim-filetypes: named files with real VimWiki"
run_case md markdown markdown
run_case md vimwiki vimwiki "$test_home/vimwiki/work/wiki/registered.md"
run_case wiki vimwiki vimwiki
run_case book book vimwiki
echo "check-vim-filetypes: ok"
