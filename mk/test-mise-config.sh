#!/bin/sh

set -eu

fail() { echo "check-mise-config: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/home" "$test_root/ancestor/checkout"
checkout=$test_root/ancestor/checkout
ln -s "$checkout" "$test_root/checkout-link"

cat > "$test_root/mise-stub" <<'EOF'
#!/bin/sh
[ "$MISE_CEILING_PATHS" = "$DOTFILES_EXPECTED_CEILING" ] || exit 42
[ "$1" = install ] || exit 43
printf '%s\n' "$*" > "$DOTFILES_MISE_LOG"
EOF
chmod +x "$test_root/mise-stub"
echo "check-mise-config: tool installation uses physical checkout ceiling"
DOTFILES_EXPECTED_CEILING="$repo" DOTFILES_MISE_LOG="$test_root/install.log" \
  make -s -C "$repo" -o mise PROFILE=lite WITH= \
    MISE_BIN="$test_root/mise-stub" mise-tools
grep -F 'install aqua:junegunn/fzf' "$test_root/install.log" >/dev/null || fail "tools were not installed"

echo "check-mise-config: offline inventory reports missing and retained tools"
mkdir -p "$test_root/installed-fzf"
cat > "$test_root/inventory-mise" <<'EOF'
#!/bin/sh
[ "$MISE_OFFLINE" = 1 ] && [ "$MISE_AUTO_INSTALL" = false ] || exit 42
[ "$MISE_GLOBAL_CONFIG_FILE" = "$DOTFILES_EXPECTED_CATALOG" ] || exit 43
[ "$MISE_CEILING_PATHS" = "$DOTFILES_EXPECTED_CEILING" ] || exit 44
case "$*" in
  'where aqua:junegunn/fzf') printf '%s\n' "$DOTFILES_INSTALLED_FZF" ;;
  'where node') exit 1 ;;
  'ls --installed --no-header rust') echo 'rust 1.94.0' ;;
  'ls --installed --no-header '*) ;;
  *) exit 45 ;;
esac
EOF
chmod +x "$test_root/inventory-mise"
DOTFILES_EXPECTED_CATALOG="$repo/setup/tools.toml" DOTFILES_EXPECTED_CEILING="$repo" \
  DOTFILES_INSTALLED_FZF="$test_root/installed-fzf" \
  sh "$repo/mk/plan-mise-tools.sh" "$repo" "$test_root/inventory-mise" \
    "$repo/setup/tools.toml" 'aqua:junegunn/fzf node' > "$test_root/inventory.log"
grep -Fxq 'missing selected installations: node' "$test_root/inventory.log" || fail 'missing installation omitted'
grep -Fxq 'installed catalog tools outside selection: rust' "$test_root/inventory.log" || fail 'retained tool omitted'

real_mise=${DOTFILES_TEST_MISE:-$HOME/.local/bin/mise}
if ! DOTFILES_PINS_FILE="$repo/setup/pins/downloads.txt" sh "$repo/mk/pinned.sh" status mise "$real_mise" >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail "pinned mise required in CI"
  echo "check-mise-config: pinned mise unavailable; skipping real config resolution"
  exit 0
fi
printf '[tools]\n"aqua:neovim/neovim" = "0.10.4"\n' > "$test_root/ancestor/mise.toml"
expected_version=$(sed -n 's/^"aqua:neovim\/neovim" = "\([^"]*\)"/\1/p' "$repo/setup/tools.toml")
[ -n "$expected_version" ] && [ "$expected_version" != 0.10.4 ] || fail "fixture and repo versions must differ"
echo "check-mise-config: ancestor config overrides without a ceiling"
resolve_version() (
  cd "$test_root/checkout-link"
  env -i HOME="$test_root/home" PATH=/usr/bin:/bin \
    MISE_DATA_DIR="$test_root/data" MISE_CACHE_DIR="$test_root/cache" \
    MISE_STATE_DIR="$test_root/state" MISE_OFFLINE=1 \
    MISE_TRUSTED_CONFIG_PATHS="$test_root/ancestor" \
    MISE_CEILING_PATHS="$1" \
    MISE_GLOBAL_CONFIG_FILE="$repo/setup/tools.toml" \
    "$real_mise" ls --current --json aqua:neovim/neovim |
    sed -n 's/.*"requested_version": "\([^"]*\)".*/\1/p'
)
[ "$(resolve_version '')" = 0.10.4 ] || fail "ancestor fixture was not selected"
echo "check-mise-config: physical ceiling isolates a symlinked checkout"
[ "$(resolve_version "$checkout")" = "$expected_version" ] || fail "ancestor replaced the repo version"
echo "check-mise-config: ok"
