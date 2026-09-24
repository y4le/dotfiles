#!/bin/sh

set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin"

cat > "$test_root/bin/cpy" <<'EOF'
#!/bin/sh
cat > "$DOTFILES_TEST_CLIPBOARD"
EOF
cat > "$test_root/bin/pst" <<'EOF'
#!/bin/sh
if [ "${DOTFILES_TEST_FAIL_PASTE:-}" = 1 ]; then
  printf 'clipboard unavailable\n' >&2
  exit 1
fi
cat "$DOTFILES_TEST_CLIPBOARD"
EOF
chmod +x "$test_root/bin/cpy" "$test_root/bin/pst"

if command -v nvim >/dev/null 2>&1; then
  echo 'check-clipboard: Neovim mappings'
  env DOTFILES_REPO="$repo" DOTFILES_TEST_CLIPBOARD="$test_root/clipboard" \
    PATH="$test_root/bin:$PATH" \
    nvim --headless -u NONE -n -l "$repo/mk/test-clipboard.lua"
elif [ -n "${CI:-}" ]; then
  echo 'check-clipboard: Neovim required in CI' >&2
  exit 1
fi

if command -v vim >/dev/null 2>&1; then
  echo 'check-clipboard: Vim paste failure'
  env DOTFILES_REPO="$repo" DOTFILES_TEST_CLIPBOARD="$test_root/clipboard" \
    DOTFILES_TEST_FAIL_PASTE=1 DOTFILES_TEST_OUTPUT="$test_root/vim.out" \
    PATH="$test_root/bin:$PATH" \
    vim -Nu NONE -n -es -S "$repo/mk/test-clipboard.vim"
  [ "$(cat "$test_root/vim.out")" = 'KEEP THIS' ] || {
    echo 'check-clipboard: failed paste changed Vim text' >&2
    exit 1
  }
elif [ -n "${CI:-}" ]; then
  echo 'check-clipboard: Vim required in CI' >&2
  exit 1
fi

echo 'check-clipboard: ok'
