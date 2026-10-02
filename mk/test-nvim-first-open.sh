#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

nvim_bin=$1
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d) || exit 1
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
  echo 'check-nvim-first-open: run make link and make nvim-plugins first' >&2
  exit 1
fi

export XDG_CONFIG_HOME="$HOME/.config"

for extension in lua sh org md wiki book; do
  file=$test_root/first-open.$extension
  filetype=$extension
  case $extension in
    lua) printf 'print("first open")\n' > "$file" ;;
    sh) printf '#!/bin/sh\necho first-open\n' > "$file" ;;
    org) printf '* TODO first open\n' > "$file" ;;
    md|wiki|book) filetype=markdown; printf '# First open\n' > "$file" ;;
  esac
  echo "check-nvim-first-open: named .$extension file"
  if ! DOTFILES_TEST_FILE="$file" DOTFILES_TEST_FILETYPE="$filetype" \
    DOTFILES_TEST_VERIFY_SCRIPT="$repo/mk/verify-nvim-first-open.lua" \
    HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 GIT_TERMINAL_PROMPT=0 \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.proxy \
    GIT_CONFIG_VALUE_0=http://127.0.0.1:9 \
    "$nvim_bin" --headless -u "$HOME/.config/nvim/init.lua" -i NONE -n \
      "$file" '+lua dofile(vim.env.DOTFILES_TEST_VERIFY_SCRIPT)' +qa \
      > "$test_root/$filetype.out" 2>&1; then
    cat "$test_root/$filetype.out" >&2
    exit 1
  fi
done

echo 'check-nvim-first-open: ok'
