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

nvim_bin=${DOTFILES_TEST_NVIM:-$(command -v nvim 2>/dev/null || true)}
if [ -n "$nvim_bin" ] && [ -x "$nvim_bin" ]; then
  echo 'check-clipboard: Neovim mappings'
  env DOTFILES_REPO="$repo" DOTFILES_TEST_CLIPBOARD="$test_root/clipboard" \
    PATH="$test_root/bin:$PATH" \
    "$nvim_bin" --headless -u NONE -i NONE -n -l "$repo/mk/test-clipboard.lua"
elif [ -n "${CI:-}" ]; then
  echo 'check-clipboard: Neovim required in CI' >&2
  exit 1
fi

if command -v vim >/dev/null 2>&1; then
  echo 'check-clipboard: Vim paste failure'
  printf 'REPLACED' > "$test_root/clipboard"
  env DOTFILES_REPO="$repo" DOTFILES_TEST_CLIPBOARD="$test_root/clipboard" \
    DOTFILES_TEST_FAIL_PASTE=1 DOTFILES_TEST_OUTPUT="$test_root/vim.out" \
    PATH="$test_root/bin:$PATH" \
    vim -Nu NONE -i NONE -n -es -S "$repo/mk/test-clipboard.vim"
  [ "$(wc -l < "$test_root/vim.out")" -eq 2 ] &&
    [ "$(sed -n '1p' "$test_root/vim.out")" = 'KEEP THIS' ] &&
    [ "$(sed -n '2p' "$test_root/vim.out")" = '' ] || {
    echo 'check-clipboard: failed paste changed Vim text' >&2
    exit 1
  }
  echo 'check-clipboard: Vim paste success'
  env DOTFILES_REPO="$repo" DOTFILES_TEST_CLIPBOARD="$test_root/clipboard" \
    DOTFILES_TEST_OUTPUT="$test_root/vim.out" PATH="$test_root/bin:$PATH" \
    vim -Nu NONE -i NONE -n -es -S "$repo/mk/test-clipboard.vim"
  [ "$(wc -l < "$test_root/vim.out")" -eq 2 ] &&
    [ "$(sed -n '1p' "$test_root/vim.out")" = 'REPLACED' ] &&
    [ "$(sed -n '2p' "$test_root/vim.out")" = '' ] || {
    echo 'check-clipboard: successful paste failed or leaked unnamed register' >&2
    exit 1
  }
elif [ -n "${CI:-}" ]; then
  echo 'check-clipboard: Vim required in CI' >&2
  exit 1
fi

echo 'check-clipboard: ok'
