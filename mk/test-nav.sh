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
zsh_bin=$(command -v zsh)

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/files" "$test_root/home"
: > "$test_root/files/two words"
: > "$test_root/files/line
break"
mkdir "$test_root/files/directory"

cat > "$test_root/bin/fzf" <<'EOF'
#!/bin/sh
cat > "$DOTFILES_NAV_INPUT"
printf 'called\n' >> "$DOTFILES_NAV_CALLS"
if [ -n "${DOTFILES_NAV_PICKER_EXIT:-}" ]; then exit "$DOTFILES_NAV_PICKER_EXIT"; fi
if [ ! -e "$DOTFILES_NAV_PICKED" ]; then
  : > "$DOTFILES_NAV_PICKED"
  printf '%s\0' "${DOTFILES_NAV_SELECTION:-./two words}"
else
  exit 130
fi
EOF
cat > "$test_root/bin/editor" <<'EOF'
#!/bin/sh
printf '%s\0' "$@" >> "$DOTFILES_NAV_OPENED"
exit "${DOTFILES_NAV_EDITOR_EXIT:-0}"
EOF
chmod +x "$test_root/bin/fzf" "$test_root/bin/editor"
cp "$test_root/bin/editor" "$test_root/bin/vim"
cp "$test_root/bin/editor" "$test_root/bin/editor with spaces"

run_nav() (
  rm -f "$test_root/picked" "$test_root/opened"
  : > "$test_root/calls"
  cd "$test_root/files" || exit 1
  env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
    DOTFILES_NAV_INPUT="$test_root/input" DOTFILES_NAV_PICKED="$test_root/picked" \
    DOTFILES_NAV_OPENED="$test_root/opened" DOTFILES_NAV_CALLS="$test_root/calls" \
    DOTFILES_NAV_SCRIPT="$repo/scripts/.config/shell/functions/nav" "$@" \
    "$zsh_bin" -f -c '
      if [[ ${DOTFILES_NAV_OPTIONS:-} == nondefault ]]; then
        setopt PIPE_FAIL KSH_ARRAYS SH_WORD_SPLIT
      fi
      if [[ ${DOTFILES_NAV_CD_FAIL:-} == 1 ]]; then
        function builtin() { print -r -- "simulated cd failure" >&2; return 37; }
      fi
      source "$DOTFILES_NAV_SCRIPT"
      nav
    '
)
expect_status() {
  label=$1
  expected_rc=$2
  shift 2
  actual_rc=0
  run_nav "$@" > "$test_root/out" 2> "$test_root/err" || actual_rc=$?
  [ "$actual_rc" -eq "$expected_rc" ] || {
    cat "$test_root/err" >&2
    fail "$label returned $actual_rc instead of $expected_rc"
  }
}
expect_args() {
  printf '%s\0' "$@" > "$test_root/expected"
  cmp -s "$test_root/opened" "$test_root/expected" || fail "editor arguments changed"
}

echo 'check-nav: filenames with spaces and newlines stay intact'
expect_status 'spaced file' 0 EDITOR="$test_root/bin/editor"
tr '\000' '\n' < "$test_root/input" | grep -Fx './two words' >/dev/null || \
  fail "nav split a filename containing spaces"
expect_args './two words'
expect_status 'newline file' 0 EDITOR="$test_root/bin/editor" DOTFILES_NAV_SELECTION='./line
break'
expect_args './line
break'
expect_status 'directory change' 0 DOTFILES_NAV_SELECTION=./directory
[ "$(tr '\000' '\n' < "$test_root/input")" = '..' ] || fail "picker did not move into the selected directory"

echo 'check-nav: quoted command arguments and executable paths'
expect_status 'quoted editor' 0 EDITOR="'$test_root/bin/editor with spaces' -c 'set nu' '' '*.txt'"
expect_args -c 'set nu' '' '*.txt' './two words'
for editor_setting in '' '   '; do
  expect_status 'blank editor fallback' 0 EDITOR="$editor_setting"
  expect_args './two words'
done
expect_status 'unset editor fallback' 0
expect_args './two words'

echo 'check-nav: editor settings are words, not executable shell code'
substitution="\$(touch $test_root/marker)"
backtick="\`touch $test_root/backtick-marker\`"
expect_status 'literal substitutions' 0 EDITOR="$test_root/bin/editor $substitution $backtick \$HOME * ;"
expect_args "$substitution" "$backtick" '$HOME' '*' ';' './two words'
[ ! -e "$test_root/marker" ] && [ ! -e "$test_root/backtick-marker" ] || \
  fail "editor settings executed shell substitutions"

echo 'check-nav: editor and directory failures return immediately'
expect_status 'editor failure' 42 EDITOR="$test_root/bin/editor" DOTFILES_NAV_EDITOR_EXIT=42
[ "$(wc -l < "$test_root/calls")" -eq 1 ] || fail "editor failure opened another picker"
expect_status 'missing editor' 127 EDITOR="$test_root/bin/not-an-editor"
expect_status 'cd failure' 37 DOTFILES_NAV_SELECTION=./directory DOTFILES_NAV_CD_FAIL=1
[ "$(wc -l < "$test_root/calls")" -eq 1 ] || fail "cd failure opened another picker"
grep -F 'simulated cd failure' "$test_root/err" >/dev/null || fail "cd error was hidden"

echo 'check-nav: cancellation differs from picker failures'
expect_status 'no match' 0 DOTFILES_NAV_PICKER_EXIT=1
expect_status 'cancel' 0 DOTFILES_NAV_PICKER_EXIT=130
expect_status 'picker error' 2 DOTFILES_NAV_PICKER_EXIT=2
grep -F 'fzf failed (status 2)' "$test_root/err" >/dev/null || fail "picker error was hidden"
mv "$test_root/bin/fzf" "$test_root/fzf"
# A stub-only PATH ensures an installed fzf cannot satisfy this case.
expect_status 'missing picker' 127 PATH="$test_root/bin"
grep -F 'fzf is not available' "$test_root/err" >/dev/null || fail "missing picker was unexplained"
mv "$test_root/fzf" "$test_root/bin/fzf"

echo 'check-nav: caller shell options do not change argument or picker handling'
cat > "$test_root/bin/find" <<'EOF'
#!/bin/sh
printf './two words\0'
exit 42
EOF
chmod +x "$test_root/bin/find"
expect_status 'caller options/partial listing' 0 EDITOR="$test_root/bin/editor" DOTFILES_NAV_OPTIONS=nondefault
expect_args './two words'

echo "check-nav: ok"
