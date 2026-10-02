#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
fail() { echo "check-cpst: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
tmux_bin=$(command -v tmux || true)
tmux_socket=$test_root/tmux.sock
cleanup() {
  [ -z "$tmux_bin" ] || "$tmux_bin" -S "$tmux_socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/entry"
ln -s "$repo/scripts/.local/bin/cpy" "$test_root/entry/cpy"
ln -s "$repo/scripts/.local/bin/pst" "$test_root/entry/pst"
printf 'text\n\n' > "$test_root/text"
for command_name in pbcopy pbpaste wl-copy wl-paste xclip tmux; do
  cat > "$test_root/bin/$command_name" <<'STUB'
#!/bin/sh
name=${0##*/}
printf '%s %s\n' "$name" "$*" >> "$DOTFILES_CLIP_LOG"
[ "$name" != "${DOTFILES_FAIL_BACKEND:-}" ] || exit 7
case "$name $*" in
  'xclip -i -sel c -f')
    [ "${DOTFILES_FAIL_X11_COPY:-}" != 1 ] || exit 9
    /bin/cat ;;
  pbpaste* | wl-paste* | 'xclip -selection clipboard -o') /bin/cat "$DOTFILES_CLIP_TEXT" ;;
  *) /bin/cat > "$DOTFILES_CLIP_CAPTURE" ;;
esac
STUB
  chmod +x "$test_root/bin/$command_name"
done

run_case() {
  : > "$test_root/log"
  env -i HOME="$test_root/unrelated-home" PATH="$test_root/bin" \
    DOTFILES_CLIP_LOG="$test_root/log" DOTFILES_CLIP_TEXT="$test_root/text" \
    DOTFILES_CLIP_CAPTURE="$test_root/copy" "$@"
}
copy_and_paste() {
  expected_copy=$1
  shift
  run_case "$@" "$test_root/entry/cpy" < "$test_root/text"
  case "$(cat "$test_root/log")" in
    "$expected_copy "*) : ;;
    *) fail "copy ignored expected backend $expected_copy" ;;
  esac
  cmp "$test_root/text" "$test_root/copy" || fail "copy changed bytes"
  run_case "$@" "$test_root/entry/pst" > "$test_root/paste"
  cmp "$test_root/text" "$test_root/paste" || fail "paste changed bytes"
}

# Run the executable through two symlink hops and with no stowed HOME helper.
echo "check-cpst: standalone macOS commands take precedence"
copy_and_paste pbcopy WAYLAND_DISPLAY=wayland-0 DISPLAY=:99
[ "$(cat "$test_root/log")" = 'pbpaste ' ] || fail "macOS backend ignored"
if run_case DOTFILES_FAIL_BACKEND=pbcopy "$test_root/entry/cpy" < "$test_root/text"; then
  fail "copy hid a backend failure"
else [ "$?" -eq 7 ] || fail "copy changed backend exit status"; fi
rm "$test_root/bin/pbcopy" "$test_root/bin/pbpaste"

echo "check-cpst: active display selects X11 or Wayland"
copy_and_paste xclip DISPLAY=:99
[ "$(cat "$test_root/log")" = 'xclip -selection clipboard -o' ] || fail "X11 paste ignored"
copy_and_paste wl-copy WAYLAND_DISPLAY=wayland-0 DISPLAY=:99
[ "$(cat "$test_root/log")" = 'wl-paste --no-newline' ] || fail "Wayland paste adds a newline"
if run_case WAYLAND_DISPLAY=wayland-0 DOTFILES_FAIL_BACKEND=wl-paste "$test_root/entry/pst"; then
  fail "paste hid a backend failure"
else [ "$?" -eq 7 ] || fail "paste changed backend status"; fi
rm "$test_root/bin/wl-copy" "$test_root/bin/wl-paste"
copy_and_paste xclip WAYLAND_DISPLAY=wayland-0 DISPLAY=:99
if run_case DISPLAY=:99 DOTFILES_FAIL_X11_COPY=1 "$test_root/entry/cpy" < "$test_root/text"; then
  fail "X11 copy pipeline hid its first failure"
else [ "$?" -eq 9 ] || fail "X11 pipeline changed failure status"; fi

echo "check-cpst: tmux copy needs no controlling terminal"
run_case TMUX=fixture SSH_CONNECTION=fixture DISPLAY=:99 "$test_root/entry/cpy" < "$test_root/text"
[ "$(cat "$test_root/log")" = 'tmux load-buffer -w -' ] || fail "SSH tmux copy used a display backend"
cmp "$test_root/text" "$test_root/copy" || fail "tmux copy changed bytes"
run_case TMUX=fixture "$test_root/entry/cpy" < "$test_root/text"
[ "$(cat "$test_root/log")" = 'tmux load-buffer -w -' ] || fail "headless tmux copy ignored tmux"
if run_case TMUX=fixture DOTFILES_FAIL_BACKEND=tmux "$test_root/entry/cpy" < "$test_root/text"; then
  fail "copy hid tmux failure"
else [ "$?" -eq 7 ] || fail "copy changed tmux exit status"; fi
rm "$test_root/bin/tmux"
if run_case TMUX=fixture "$test_root/entry/cpy" < "$test_root/text" 2> "$test_root/error"; then
  fail "copy succeeded without tmux"
else [ "$?" -eq 127 ] || fail "missing tmux returned wrong status"; fi
if run_case "$test_root/entry/pst" 2> "$test_root/error"; then
  fail "headless paste fabricated a clipboard"
fi
grep -q 'no clipboard command found' "$test_root/error" || fail "paste error was not explained"
if run_case "$test_root/entry/cpy" unexpected 2> "$test_root/error"; then
  fail "copy ignored unexpected arguments"
else [ "$?" -eq 2 ] || fail "copy returned wrong usage status"; fi

if [ -n "$tmux_bin" ]; then
  echo "check-cpst: real tmux buffer transfer without an attached client"
  env -i HOME="$test_root" PATH="/usr/bin:/bin" SHELL=/bin/sh \
    "$tmux_bin" -S "$tmux_socket" -f /dev/null new-session -d -s clipboard 'exec sleep 300'
  env -i HOME="$test_root/unrelated-home" PATH="$(dirname "$tmux_bin"):/usr/bin:/bin" \
    TMUX="$tmux_socket,0,0" SSH_CONNECTION=fixture \
    "$test_root/entry/cpy" < "$test_root/text"
  "$tmux_bin" -S "$tmux_socket" save-buffer "$test_root/tmux-copy"
  cmp "$test_root/text" "$test_root/tmux-copy" || fail "real tmux transfer changed bytes"
fi

if command -v python3 >/dev/null 2>&1; then
  python3 -I "$repo/mk/test-cpst-pty.py" "$repo/scripts/.local/bin/cpy" "$test_root"
elif [ -n "${CI:-}" ]; then
  fail "python3 required for isolated OSC 52 tests"
else
  echo "check-cpst: python3 absent; isolated OSC 52 tests skipped"
fi

echo "check-cpst: ok"
