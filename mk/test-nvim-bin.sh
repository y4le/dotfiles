#!/bin/sh

set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
# shellcheck source=mk/test-lib.sh
. "$repo/mk/test-lib.sh"
test_init check-nvim-bin
mkdir -p "$test_root/bin" "$test_root/empty"

printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_root/preferred-nvim"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_root/bin/nvim"
cat > "$test_root/mise" <<'EOF'
#!/bin/sh
[ "$MISE_GLOBAL_CONFIG_FILE" = "$DOTFILES_EXPECTED_MISE_CONFIG" ] || exit 1
[ "$MISE_CEILING_PATHS" = "$DOTFILES_EXPECTED_CEILING" ] || exit 1
[ "$1" = which ] && [ "$2" = nvim ] || exit 1
printf '%s\n' "$DOTFILES_MISE_NVIM"
EOF
chmod +x "$test_root/preferred-nvim" "$test_root/bin/nvim" "$test_root/mise"

find_nvim() {
  env -i PATH="$2" DOTFILES_MISE_NVIM="$1" \
    DOTFILES_EXPECTED_CEILING="$repo" \
    DOTFILES_EXPECTED_MISE_CONFIG="$test_root/config.toml" \
    /bin/sh "${3:-$repo/mk/find-nvim.sh}" "$test_root/mise" "$test_root/config.toml"
}

echo "check-nvim-bin: prefer the executable selected by mise"
selected=$(find_nvim "$test_root/preferred-nvim" "$test_root/bin") || \
  fail "mise selection failed"
[ "$selected" = "$test_root/preferred-nvim" ] || \
  fail "mise Neovim was not preferred"

echo "check-nvim-bin: discovery uses the physical root through a checkout symlink"
ln -s "$repo" "$test_root/checkout-link"
selected=$(find_nvim "$test_root/preferred-nvim" "$test_root/bin" \
  "$test_root/checkout-link/mk/find-nvim.sh") || fail "symlinked checkout selection failed"
[ "$selected" = "$test_root/preferred-nvim" ] || fail "symlinked checkout lost mise selection"

echo "check-nvim-bin: fall back when mise returns an unusable path"
selected=$(find_nvim "$test_root/missing-nvim" "$test_root/bin") || \
  fail "PATH fallback failed"
[ "$selected" = "$test_root/bin/nvim" ] || \
  fail "PATH Neovim was not selected"

echo "check-nvim-bin: report when no executable is available"
if find_nvim "$test_root/missing-nvim" "$test_root/empty" \
  > "$test_root/missing.out" 2>&1; then
  fail "missing Neovim was accepted"
fi
grep -F "Install it with 'make tools'" "$test_root/missing.out" >/dev/null || \
  fail "missing Neovim had no actionable diagnostic"

echo "check-nvim-bin: ok"
