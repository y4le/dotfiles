#!/bin/sh

set -eu
fail() { echo "check-yazi: $*" >&2; exit 1; }
if ! command -v zsh >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail "zsh is required"
  echo 'check-yazi: zsh absent; skipping outside CI'
  exit 0
fi
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
zsh_bin=$(command -v zsh)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/tmp" "$test_root/directory with spaces"
cat > "$test_root/bin/yazi" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "$DOTFILES_YAZI_ARGS"
case $1 in --cwd-file=*) cwd_file=${1#--cwd-file=} ;; *) exit 9 ;; esac
printf '%s' "$DOTFILES_YAZI_CWD" > "$cwd_file"
exit "${DOTFILES_YAZI_EXIT:-0}"
STUB
chmod +x "$test_root/bin/yazi"
for tool in mktemp rm; do ln -s "$(command -v "$tool")" "$test_root/bin/$tool"; done
run_y() {
  env -i HOME="$test_root" PATH="$test_root/bin" TMPDIR="$test_root/tmp" \
    DOTFILES_YAZI_HELPER="$repo/scripts/.config/shell/functions/y" \
    DOTFILES_YAZI_ARGS="$test_root/args" DOTFILES_YAZI_OUTPUT="$test_root/output" \
    "$@" "$zsh_bin" -f -c '
      setopt errexit nounset
      source "$DOTFILES_YAZI_HELPER"
      result=0
      y -- "path with spaces" || result=$?
      print -rn -- "$PWD" > "$DOTFILES_YAZI_OUTPUT"
      exit "$result"
    '
}
echo 'check-yazi: caller directory, option order, cleanup and failure status'
run_y DOTFILES_YAZI_CWD="$test_root/directory with spaces"
[ "$(cat "$test_root/output")" = "$test_root/directory with spaces" ] || fail "y did not change caller directory"
[ "$(sed -n '2p' "$test_root/args")" = -- ] || fail "wrapper option did not precede user --"
[ "$(sed -n '3p' "$test_root/args")" = 'path with spaces' ] || fail "user arguments split"
if run_y DOTFILES_YAZI_CWD="$test_root/directory with spaces" DOTFILES_YAZI_EXIT=7; then
  fail "Yazi failure was hidden"
else [ "$?" -eq 7 ] || fail "Yazi exit status changed"; fi
[ "$(cat "$test_root/output")" = "$(pwd -P)" ] || fail "failed Yazi changed caller directory"
if run_y DOTFILES_YAZI_CWD="$test_root/missing-directory" 2> "$test_root/error"; then
  fail "directory-change failure was hidden"
fi
run_y DOTFILES_YAZI_CWD=
[ "$(cat "$test_root/output")" = "$(pwd -P)" ] || fail "empty cwd file changed directory"
[ -z "$(ls -A "$test_root/tmp")" ] || fail "temporary cwd files leaked"
rm "$test_root/bin/yazi"
if run_y DOTFILES_YAZI_CWD= > "$test_root/stdout" 2> "$test_root/error"; then
  fail "missing Yazi was accepted"
else [ "$?" -eq 127 ] || fail "missing Yazi returned wrong status"; fi
[ ! -s "$test_root/stdout" ] || fail "missing tool diagnostic went to stdout"
grep -q 'yazi not found' "$test_root/error" || fail "missing tool diagnostic absent"
echo 'check-yazi: ok'
