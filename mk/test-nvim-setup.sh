#!/bin/sh

set -eu

nvim_bin=$1
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/home" "$test_root/plugin/parser"
export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"

echo 'check-nvim-setup: file arguments retain read events'
cat > "$test_root/init.lua" <<'EOF'
dofile(vim.env.DOTFILES_TEST_OPTIONS)
vim.api.nvim_create_autocmd({ "BufReadPre", "BufReadPost" }, {
  callback = function(args)
    vim.fn.writefile({ args.event }, vim.env.DOTFILES_TEST_EVENTS, "a")
  end,
})
EOF
printf 'return true\n' > "$test_root/file.lua"
DOTFILES_TEST_OPTIONS="$repo/nvim/.config/nvim/lua/config/options.lua" \
  DOTFILES_TEST_EVENTS="$test_root/events" \
  "$nvim_bin" --headless -u "$test_root/init.lua" -i NONE -n \
    "$test_root/file.lua" +qa > "$test_root/startup.out" 2>&1 || {
    cat "$test_root/startup.out" >&2
    exit 1
  }
[ "$(cat "$test_root/events")" = 'BufReadPre
BufReadPost' ] || {
  echo 'check-nvim-setup: opening a named file skipped read events' >&2
  exit 1
}

echo 'check-nvim-setup: parser restore reports missing artifacts'
cat > "$test_root/check-parsers.lua" <<'EOF'
package.loaded["lazy.core.config"] = {
  plugins = { ["nvim-treesitter"] = { dir = vim.env.DOTFILES_TEST_PLUGIN_DIR } },
}
dofile(vim.env.DOTFILES_NVIM_PARSER_VERIFY_SCRIPT)
EOF
printf '' > "$test_root/plugin/parser/lua.so"
DOTFILES_TEST_PLUGIN_DIR="$test_root/plugin" \
  DOTFILES_NVIM_PARSERS='lua' \
  DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="$repo/mk/verify-nvim-parsers.lua" \
  "$nvim_bin" --headless -u NONE -i NONE -n -l "$test_root/check-parsers.lua" \
    > "$test_root/parser-present.out" 2>&1 || {
    cat "$test_root/parser-present.out" >&2
    exit 1
  }
rm "$test_root/plugin/parser/lua.so"
if DOTFILES_TEST_PLUGIN_DIR="$test_root/plugin" \
  DOTFILES_NVIM_PARSERS='lua' \
  DOTFILES_NVIM_PARSER_VERIFY_SCRIPT="$repo/mk/verify-nvim-parsers.lua" \
  "$nvim_bin" --headless -u NONE -i NONE -n -l "$test_root/check-parsers.lua" \
    > "$test_root/parser-missing.out" 2>&1; then
  echo 'check-nvim-setup: missing parser was accepted' >&2
  exit 1
fi
grep -F 'missing Neovim Treesitter parsers: lua' \
  "$test_root/parser-missing.out" >/dev/null || {
  cat "$test_root/parser-missing.out" >&2
  exit 1
}

echo 'check-nvim-setup: ok'
