#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
fail() { echo "check-i3blocks: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/home/.local/libexec/i3blocks" "$test_root/nested blocks/memory"
helper=$repo/linux-desktop/.config/i3blocks/blocklet
cat > "$test_root/fixture" <<'EOF'
#!/bin/sh
printf '%s|%s|%s\n' "$BLOCK_NAME" "${BLOCK_INSTANCE:-}" "${1:-}"
exit "${DOTFILES_BLOCK_EXIT:-0}"
EOF
chmod +x "$test_root/fixture"
cp "$test_root/fixture" "$test_root/home/.local/libexec/i3blocks/memory"
cp "$test_root/fixture" "$test_root/nested blocks/memory/memory"

actual=$(env -i HOME="$test_root/home" BLOCK_NAME=memory BLOCK_INSTANCE=swap \
  sh "$helper" argument)
[ "$actual" = 'memory|swap|argument' ] || fail "user libexec blocklet or environment/argument forwarding failed"
actual=$(env -i HOME="$test_root/home" BLOCK_NAME=memory \
  I3BLOCKS_SCRIPT_DIR="$test_root/nested blocks" sh "$helper")
[ "$actual" = 'memory||' ] || fail "nested contrib layout with spaces failed"
if env -i HOME="$test_root/home" BLOCK_NAME=memory DOTFILES_BLOCK_EXIT=42 \
  sh "$helper" > "$test_root/failure"; then
  fail "blocklet failure was accepted"
else
  [ "$?" -eq 42 ] || fail "blocklet failure status changed"
fi
chmod -x "$test_root/nested blocks/memory/memory"
if env -i HOME="$test_root/home" BLOCK_NAME=memory \
  I3BLOCKS_SCRIPT_DIR="$test_root/nested blocks" sh "$helper" \
  > "$test_root/missing.out" 2> "$test_root/missing.err"; then
  fail "non-executable blocklet was accepted or explicit directory ignored"
fi
grep -F '[missing memory]' "$test_root/missing.out" >/dev/null || fail "missing blocklet is invisible in the bar"
grep -F 'install compatible blocklets' "$test_root/missing.err" >/dev/null || fail "missing dependency is unexplained"
if env -i HOME="$test_root/home" BLOCK_NAME=../fixture sh "$helper" \
  > "$test_root/invalid.out" 2> "$test_root/invalid.err"; then
  fail "unsupported block name was accepted"
fi
echo 'check-i3blocks: ok'
