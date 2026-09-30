#!/bin/sh

set -eu
fail() { echo "check-cpst: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin"
for command_name in pbcopy pbpaste wl-copy wl-paste xclip; do
  printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "$DOTFILES_CLIP_LOG"\n' "$command_name" > "$test_root/bin/$command_name"
  chmod +x "$test_root/bin/$command_name"
done

run_case() {
  backend_path=$1
  shift
  : > "$test_root/log"
  env -i HOME="$test_root" PATH="$backend_path" DOTFILES_CLIP_LOG="$test_root/log" \
    DOTFILES_CPST="$repo/scripts/.config/shell/functions/cpst" "$@"
}

echo "check-cpst: macOS commands take precedence"
run_case "$test_root/bin" WAYLAND_DISPLAY=wayland-0 DISPLAY=:99 /bin/bash -c '
  source "$DOTFILES_CPST"; cpy </dev/null; pst
'
grep -q '^pbcopy' "$test_root/log" && grep -q '^pbpaste' "$test_root/log" || fail "macOS backend ignored"
[ "$(wc -l < "$test_root/log")" -eq 2 ] || fail "macOS used another backend"
rm "$test_root/bin/pbcopy" "$test_root/bin/pbpaste"

echo "check-cpst: X11 ignores installed Wayland commands"
run_case "$test_root/bin" DISPLAY=:99 /bin/bash -c '
  source "$DOTFILES_CPST"; cpy </dev/null; pst; [[ $DISPLAY == :99 ]]
'
[ "$(wc -l < "$test_root/log")" -eq 3 ] || fail "X11 did not use xclip copy and paste"
! grep -q '^wl-' "$test_root/log" || fail "X11 selected Wayland"
grep -q 'xclip -selection clipboard -o' "$test_root/log" || fail "X11 paste missing"

echo "check-cpst: Wayland wins when both displays are available"
run_case "$test_root/bin" WAYLAND_DISPLAY=wayland-0 DISPLAY=:99 /bin/bash -c '
  source "$DOTFILES_CPST"; cpy </dev/null; pst
'
grep -q '^wl-copy' "$test_root/log" && grep -q '^wl-paste' "$test_root/log" || fail "Wayland backend ignored"
[ "$(wc -l < "$test_root/log")" -eq 2 ] || fail "Wayland used another backend"

echo "check-cpst: missing Wayland commands fall back to active X11"
rm "$test_root/bin/wl-copy" "$test_root/bin/wl-paste"
run_case "$test_root/bin" WAYLAND_DISPLAY=wayland-0 DISPLAY=:99 /bin/bash -c '
  source "$DOTFILES_CPST"; cpy </dev/null; pst
'
[ "$(wc -l < "$test_root/log")" -eq 3 ] || fail "Wayland command absence blocked X11 fallback"

echo "check-cpst: no display never fabricates DISPLAY"
run_case "$test_root/bin" /bin/bash -c '
  source "$DOTFILES_CPST"
  _osc52_copy() { printf "osc52\n" >> "$DOTFILES_CLIP_LOG"; }
  cpy </dev/null
  if pst; then exit 2; fi
  [[ ${DISPLAY-unset} == unset ]]
' 2> "$test_root/no-display.err"
[ "$(cat "$test_root/log")" = osc52 ] || fail "no-display copy used a graphical backend"
grep -q 'no clipboard command found' "$test_root/no-display.err" || fail "paste failure was not explained"

echo "check-cpst: SSH copy stays on OSC 52"
run_case "$test_root/bin" DISPLAY=:99 SSH_CONNECTION=fixture /bin/bash -c '
  source "$DOTFILES_CPST"
  _osc52_copy() { printf "osc52\n" >> "$DOTFILES_CLIP_LOG"; }
  cpy </dev/null
'
[ "$(cat "$test_root/log")" = osc52 ] || fail "SSH copied into the host display"
echo "check-cpst: ok"
