#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

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
vim.opt.rtp:prepend(vim.env.DOTFILES_REPO .. "/nvim/.config/nvim")
dofile(vim.env.DOTFILES_TEST_OPTIONS)
vim.api.nvim_create_autocmd({ "BufReadPre", "BufReadPost" }, {
  callback = function(args)
    vim.fn.writefile({ args.event }, vim.env.DOTFILES_TEST_EVENTS, "a")
  end,
})
EOF
printf 'return true\n' > "$test_root/file.lua"
DOTFILES_REPO="$repo" DOTFILES_TEST_OPTIONS="$repo/nvim/.config/nvim/lua/config/options.lua" \
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

echo 'check-nvim-setup: plugin verification survives removed error API'
cat > "$test_root/check-plugins.lua" <<'EOF'
vim.api.nvim_err_writeln = nil
package.loaded["lazy.core.config"] = {
  plugins = { fixture = { dir = "fixture", _ = { is_local = false } } },
  spec = { disabled = {}, ignore_installed = {} },
}
package.loaded["lazy.manage.git"] = {
  info = function() return { commit = "actual" } end,
}
dofile(vim.env.DOTFILES_NVIM_PLUGIN_VERIFY_SCRIPT)
EOF
check_plugins() {
  DOTFILES_NVIM_LOCK_SNAPSHOT="$test_root/lock.json" \
    DOTFILES_NVIM_PLUGIN_VERIFY_SCRIPT="$repo/mk/verify-nvim-plugins.lua" \
    DOTFILES_TEST_PLUGIN_FIXTURE="$test_root/check-plugins.lua" \
    "$nvim_bin" --headless -u NONE -i NONE -n \
      '+lua dofile(vim.env.DOTFILES_TEST_PLUGIN_FIXTURE)' +qa
}
printf '%s\n' '{"fixture":{"commit":"actual"}}' > "$test_root/lock.json"
check_plugins > "$test_root/plugins-present.out" 2>&1 || {
  cat "$test_root/plugins-present.out" >&2
  exit 1
}
printf '%s\n' '{"fixture":{"commit":"expected"}}' > "$test_root/lock.json"
if check_plugins > "$test_root/plugins-mismatch.out" 2>&1; then
  echo 'check-nvim-setup: plugin mismatch was accepted' >&2
  exit 1
fi
grep -F 'Neovim plugin fixture mismatch: expected expected, got actual' \
  "$test_root/plugins-mismatch.out" >/dev/null || {
  cat "$test_root/plugins-mismatch.out" >&2
  exit 1
}
rm "$test_root/lock.json"
if check_plugins > "$test_root/plugins-error.out" 2>&1; then
  echo 'check-nvim-setup: verifier exception was accepted' >&2
  exit 1
fi
grep -F 'lock.json' "$test_root/plugins-error.out" >/dev/null || {
  cat "$test_root/plugins-error.out" >&2
  exit 1
}

echo 'check-nvim-setup: ok'
