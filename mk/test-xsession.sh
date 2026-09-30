#!/bin/sh

set -eu
fail() { echo "check-xsession: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir "$test_root/bin"

run_session() {
  env -i PATH="$test_root/bin" DOTFILES_SESSION="$repo/linux-desktop/.xsessionrc" \
    DOTFILES_XSETROOT_LOG="$test_root/log" DOTFILES_XSETROOT_EXIT="$1" \
    /bin/sh -ec '. "$DOTFILES_SESSION"; printf "%s|%s\n" "$GTK_IM_MODULE" "$TERMINAL"'
}

echo 'check-xsession: missing optional xsetroot does not abort login'
actual=$(run_session 0 2> "$test_root/missing.err") || fail "missing xsetroot aborted the session"
[ "$actual" = 'xim|kitty' ] || fail "missing xsetroot skipped session settings"
[ ! -s "$test_root/missing.err" ] || fail "missing optional tool produced an error"
cat > "$test_root/bin/xsetroot" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$DOTFILES_XSETROOT_LOG"
exit "$DOTFILES_XSETROOT_EXIT"
EOF
chmod +x "$test_root/bin/xsetroot"
echo 'check-xsession: available xsetroot sets the configured background'
actual=$(run_session 0) || fail "successful xsetroot aborted the session"
[ "$actual" = 'xim|kitty' ] || fail "session settings changed"
[ "$(cat "$test_root/log")" = '-solid #333333' ] || fail "background arguments changed"
echo 'check-xsession: failed optional xsetroot is reported without aborting'
actual=$(run_session 42 2> "$test_root/failure.err") || fail "failed xsetroot aborted the session"
[ "$actual" = 'xim|kitty' ] || fail "failed xsetroot skipped session settings"
grep -F 'could not set the desktop background' "$test_root/failure.err" >/dev/null || \
  fail "xsetroot failure was not explained"
echo 'check-xsession: ok'
