#!/bin/sh

set -eu

fail() {
  echo "check-nav: $*" >&2
  exit 1
}

if ! command -v zsh >/dev/null 2>&1; then
  echo "check-nav: zsh not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-nav: skipping outside CI"
  exit 0
fi

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/files" "$test_root/home"
: > "$test_root/files/two words"

cat > "$test_root/bin/fzf" <<'EOF'
#!/bin/sh
cat > "$DOTFILES_NAV_INPUT"
if [ ! -e "$DOTFILES_NAV_PICKED" ]; then
  : > "$DOTFILES_NAV_PICKED"
  printf './two words\0'
fi
EOF
cat > "$test_root/bin/editor" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$DOTFILES_NAV_OPENED"
EOF
chmod +x "$test_root/bin/fzf" "$test_root/bin/editor"

echo "check-nav: filenames with spaces stay intact"
(
  cd "$test_root/files" || exit 1
  env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
    EDITOR="$test_root/bin/editor" DOTFILES_NAV_INPUT="$test_root/input" \
    DOTFILES_NAV_PICKED="$test_root/picked" \
    DOTFILES_NAV_OPENED="$test_root/opened" \
    DOTFILES_NAV_SCRIPT="$repo/scripts/.config/shell/functions/nav" \
    zsh -f -c 'source "$DOTFILES_NAV_SCRIPT"; nav'
) || fail "nav failed"
tr '\000' '\n' < "$test_root/input" | grep -Fx './two words' >/dev/null || \
  fail "nav split a filename containing spaces"
[ "$(cat "$test_root/opened")" = './two words' ] || \
  fail "nav opened the wrong file"

echo "check-nav: ok"
