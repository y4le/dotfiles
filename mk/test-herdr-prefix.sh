#!/bin/sh

set -eu

fail() {
  echo "check-herdr: $*" >&2
  exit 1
}

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

# Stow-shaped home: config.toml links into a fake checkout.
home=$test_root/home
checkout=$test_root/checkout
mkdir -p "$home/.config/herdr" "$checkout" "$test_root/bin"
ln -s "$repo/herdr/.config/herdr/herdr-prefix" "$home/.config/herdr/herdr-prefix"
ln -s ../../../checkout/config.toml "$home/.config/herdr/config.toml"
config=$checkout/config.toml
tool=$home/.config/herdr/herdr-prefix

# Stand-in herdr: `config check` fails when the candidate contains FAILCHECK;
# `server reload-config` is recorded.
cat > "$test_root/bin/herdr" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "config check") ! grep -q FAILCHECK "$HERDR_CONFIG_PATH" ;;
  "server reload-config") echo reload >> "$HERDR_TEST_LOG" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$test_root/bin/herdr"

run() {
  HOME=$home HERDR_PREFIXES='ctrl+b ctrl+a ctrl+space' \
    HERDR_CONFIG_PATH=$home/.config/herdr/config.toml \
    HERDR_BIN_PATH=$test_root/bin/herdr HERDR_TEST_LOG=$test_root/log \
    bash "$tool" "$@"
}

# A multiline string holding blank lines and lines that look like structure,
# after triple quotes that only appear in a comment or single-line strings.
cat > "$config" <<'EOF'
onboarding = false # three quotes: """

[keys]
navigate_workspace_up = ["up", "k"]

[[keys.command]]
key = "prefix+alt+t"
type = "shell"
command = "true"
description = '"""'

[[keys.command]]
key = "prefix+alt+u"
type = "shell"
command = "true"
description = "escaped \" then \"\"\" and '''"

[[keys.command]]
key = "prefix+alt+g"
type = "popup"
command = "lazygit"
description = """
[keys]
prefix = "ctrl+z"


# END herdr-prefix
"""
EOF
chmod 640 "$config"
original=$(cat "$config")

echo "check-herdr: set writes through the Stow link"
run set ctrl+a
[ -L "$home/.config/herdr/config.toml" ] || fail "config link was replaced"
[ "$(ls -l "$config" | cut -c1-10)" = "-rw-r-----" ] || fail "config mode changed"
[ "$(run get)" = ctrl+a ] || fail "get did not report ctrl+a"
if ! grep -q '^key = "prefix+ctrl+b"$' "$config"; then
  sed -n '/^# BEGIN herdr-prefix/,$p' "$config" >&2
  fail "missing ctrl+b switch"
fi
grep -q '^key = "prefix+ctrl+space"$' "$config" || fail "missing ctrl+space switch"
! grep -q '^key = "prefix+ctrl+a"$' "$config" || fail "generated reserved ctrl+a switch"
grep -q '^command = "\$HOME/.config/herdr/herdr-prefix set ctrl+b"$' "$config" || \
  fail "switch command is not \$HOME-relative"
[ "$(grep -c reload "$test_root/log")" = 1 ] || fail "server was not reloaded"

echo "check-herdr: multiline strings are preserved"
multiline='description = """
[keys]
prefix = "ctrl+z"


# END herdr-prefix
"""'
case $(cat "$config") in
  *"$multiline"*) ;;
  *) fail "multiline string changed" ;;
esac
[ "$(grep -c '^prefix = ' "$config")" = 2 ] || fail "prefix lines were added or dropped"

echo "check-herdr: reset round-trips byte-for-byte"
run reset
after_reset=$(cat "$config")
run set ctrl+space
run reset
[ "$(cat "$config")" = "$after_reset" ] || fail "set then reset changed the config"
stripped=$(printf '%s\n' "$after_reset" | sed -e '/^prefix = "ctrl+b"  # herdr-prefix$/d' \
  -e '/^# BEGIN herdr-prefix/,$d')
[ "$stripped" = "$original" ] || fail "reset changed unrelated config bytes"

echo "check-herdr: quoted keys and CRLF line endings"
cr=$(printf '\r')
printf 'onboarding = false\r\n\r\n["keys"]\r\n"prefix" = '"'"'ctrl+b'"'"'\r\n' > "$config"
[ "$(run get)" = ctrl+b ] || fail "get missed a single-quoted prefix"
run set ctrl+a
[ "$(run get)" = ctrl+a ] || fail "get missed the CRLF prefix"
[ "$(grep -Ec '"prefix" = |^prefix = ' "$config")" = 1 ] || fail "quoted prefix was not replaced"
[ "$(grep -c '^\[' "$config")" = 3 ] || fail "added a table beside quoted [keys]"
[ -z "$(grep -v "$cr\$" "$config")" ] || fail "wrote a line without CRLF"
run set ctrl+space
[ "$(grep -c '^# BEGIN herdr-prefix' "$config")" = 1 ] || fail "CRLF managed block was duplicated"

echo "check-herdr: failures leave the config unchanged"
before=$(cat "$config")
if run set ctrl+x 2>/dev/null; then fail "accepted an unknown prefix"; fi
printf '# FAILCHECK\n' >> "$config"
before=$(cat "$config")
if run set ctrl+a 2>/dev/null; then fail "ignored a failed config check"; fi
[ "$(cat "$config")" = "$before" ] || fail "failed check modified the config"
mkdir "$home/.config/herdr/config.toml.herdr-prefix.lock"
sed -i.orig '/FAILCHECK/d' "$config" && rm -f "$config.orig"
before=$(cat "$config")
if run set ctrl+a 2>/dev/null; then fail "ignored a held lock"; fi
[ "$(cat "$config")" = "$before" ] || fail "locked switch modified the config"
rmdir "$home/.config/herdr/config.toml.herdr-prefix.lock"
leftovers=$(find "$checkout" "$home/.config/herdr" -name '.herdr-prefix.*' -o -name '*.lock')
[ -z "$leftovers" ] || fail "left temporary files: $leftovers"
