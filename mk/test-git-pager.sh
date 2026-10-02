#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

fail() {
  echo "check-git: $*" >&2
  exit 1
}

test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin"
ln -s /bin/cat "$test_root/bin/cat"
cat > "$test_root/bin/less" <<'EOF'
#!/bin/sh
printf 'less %s\n' "$*" >> "$TEST_LOG"
exec /bin/cat
EOF
chmod +x "$test_root/bin/less"

config=git/.config/git/config
pager=$(git config --file "$config" --get core.pager) || fail 'missing core.pager'
filter=$(git config --file "$config" --get interactive.diffFilter) || \
  fail 'missing interactive.diffFilter'
export TEST_LOG="$test_root/log"
printf 'one\ntwo\n' > "$test_root/input"

for command in "$pager" "$filter"; do
  PATH="$test_root/bin" /bin/sh -c "$command" < "$test_root/input" > "$test_root/output" || \
    fail 'command failed without delta'
  cmp -s "$test_root/input" "$test_root/output" || \
    fail 'command changed input without delta'
done
grep -Fqx 'less -FRX' "$TEST_LOG" || fail 'pager did not fall back to less'

cat > "$test_root/bin/delta" <<'EOF'
#!/bin/sh
printf 'delta %s\n' "$*" >> "$TEST_LOG"
exec /bin/cat
EOF
chmod +x "$test_root/bin/delta"
for command in "$pager" "$filter"; do
  PATH="$test_root/bin" /bin/sh -c "$command" < "$test_root/input" > "$test_root/output" || \
    fail 'command failed with delta'
  cmp -s "$test_root/input" "$test_root/output" || \
    fail 'command changed input with delta'
done
grep -Fqx 'delta ' "$TEST_LOG" || fail 'pager did not use delta'
grep -Fqx 'delta --color-only' "$TEST_LOG" || \
  fail 'interactive filter did not use delta --color-only'

echo 'check-git: pager and patch filter fallbacks ok'
