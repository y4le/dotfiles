#!/bin/sh

set -u

fail() {
  echo "check-runtime: $*" >&2
  exit 1
}

if ! command -v zsh >/dev/null 2>&1; then
  echo "check-runtime: zsh not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-runtime: skipping outside CI"
  exit 0
fi
if ! command -v stow >/dev/null 2>&1; then
  echo "check-runtime: stow not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-runtime: skipping outside CI"
  exit 0
fi

test_root=$(mktemp -d) || exit 1
tmux_bin=$(command -v tmux 2>/dev/null || true)
tmux_missing_socket=/tmp/dotfiles-tmux-missing.$$
tmux_restored_socket=/tmp/dotfiles-tmux-restored.$$
cleanup() {
  if [ -n "$tmux_bin" ]; then
    "$tmux_bin" -S "$tmux_missing_socket" kill-server >/dev/null 2>&1 || true
    "$tmux_bin" -S "$tmux_restored_socket" kill-server >/dev/null 2>&1 || true
  fi
  rm -f "$tmux_missing_socket" "$tmux_restored_socket"
  rm -rf "$test_root"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

repo=$(pwd -P) || exit 1
test_home=$test_root/home
mkdir -p "$test_home"
stow -R --no-folding -d "$repo" -t "$test_home" zsh scripts tmux >/dev/null 2>&1 || \
  fail "could not prepare the test HOME"

runtime_log=$test_root/network.log
: > "$runtime_log"
for command_name in sheldon curl wget; do
  stub=$test_home/bin/$command_name
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\\n" "$0 $*" >> "$DOTFILES_RUNTIME_LOG"' \
    'exit 97' > "$stub"
  chmod +x "$stub"
done

mkdir -p "$test_home/.config/zsh/sources"
printf '%s\n' 'typeset -g DOTFILES_SOURCE_MARKER=loaded' > \
  "$test_home/.config/zsh/sources/runtime-test.zsh"
printf '%s\n' 'typeset -g DOTFILES_POST_MARKER=loaded' > \
  "$test_home/.post_profile"

run_zsh() {
  env -i \
    HOME="$test_home" \
    PATH="${DOTFILES_TEST_PATH_PREFIX:-}/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh \
    TERM=dumb \
    LC_ALL=C \
    DOTFILES_RUNTIME_LOG="$runtime_log" \
    HTTPS_PROXY=http://127.0.0.1:9 \
    HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 \
    zsh "$@"
}

echo "check-runtime: zsh without restored plugins"
if ! run_zsh -i -c \
  'print -r -- "$HISTFILE|$DOTFILES_SOURCE_MARKER|$DOTFILES_POST_MARKER"' \
  > "$test_root/no-cache.out" 2> "$test_root/no-cache.err"; then
  fail "interactive zsh failed without optional tools"
fi
[ "$(cat "$test_root/no-cache.out")" = \
  "$test_home/.history|loaded|loaded" ] || \
  fail "interactive zsh skipped normal configuration"
[ "$(grep -Fc "dotfiles: zsh plugins not restored; run 'make plugins'" \
  "$test_root/no-cache.err")" -eq 1 ] || \
  fail "interactive zsh did not print exactly one restore hint"
[ ! -s "$runtime_log" ] || fail "zsh startup invoked a network-capable command"

echo "check-runtime: zsh with restored cache"
cache=$test_home/.cache/dotfiles/sheldon.zsh
mkdir -p "$(dirname "$cache")"
printf '%s\n' 'typeset -g DOTFILES_CACHE_MARKER=loaded' > "$cache"
: > "$runtime_log"
if ! run_zsh -i -c 'print -r -- "$DOTFILES_CACHE_MARKER"' \
  > "$test_root/cache.out" 2> "$test_root/cache.err"; then
  fail "interactive zsh failed with a restored cache"
fi
[ "$(cat "$test_root/cache.out")" = loaded ] || \
  fail "interactive zsh did not source the restored cache"
if grep -Fq 'dotfiles: zsh plugins not restored' "$test_root/cache.err"; then
  fail "interactive zsh warned despite a restored cache"
fi
[ ! -s "$runtime_log" ] || fail "cached zsh startup invoked sheldon or a downloader"

echo "check-runtime: failed cache refresh preserves the last good cache"
failing_sheldon=$test_root/failing-sheldon
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1" in' \
  '  lock) exit 0 ;;' \
  '  source) printf "%s\\n" "partial cache"; exit 2 ;;' \
  'esac' > "$failing_sheldon"
chmod +x "$failing_sheldon"
cp "$cache" "$test_root/cache.before"
if env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
  SHELL=/bin/sh LC_ALL=C make -C "$repo" .SHELLFLAGS=-c \
  SHELDON_BIN="$failing_sheldon" sheldon-plugins \
  > "$test_root/cache-refresh.out" 2>&1; then
  fail "failed sheldon source was accepted"
fi
cmp -s "$cache" "$test_root/cache.before" || \
  fail "failed sheldon source replaced the good cache"

failing_lock=$test_root/failing-sheldon-lock
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1" in' \
  '  lock) exit 2 ;;' \
  '  source) printf "%s\\n" "unexpected cache"; exit 0 ;;' \
  'esac' > "$failing_lock"
chmod +x "$failing_lock"
if env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
  SHELL=/bin/sh LC_ALL=C make -C "$repo" .SHELLFLAGS=-c \
  SHELDON_BIN="$failing_lock" sheldon-plugins \
  > "$test_root/cache-lock.out" 2>&1; then
  fail "failed sheldon lock was accepted"
fi
cmp -s "$cache" "$test_root/cache.before" || \
  fail "failed sheldon lock replaced the good cache"

echo "check-runtime: non-interactive zshenv"
: > "$runtime_log"
for command_name in bat delta mise; do
  stub=$test_home/bin/$command_name
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\\n" "$0 $*" >> "$DOTFILES_RUNTIME_LOG"' \
    'exit 97' > "$stub"
  chmod +x "$stub"
done
DOTFILES_TEST_PATH_PREFIX="$test_home/bin:" run_zsh -c true \
  > "$test_root/non-interactive.out" \
  2> "$test_root/non-interactive.err" || fail "non-interactive zsh failed"
[ ! -s "$runtime_log" ] || fail ".zshenv invoked an external probe"
if grep -Eq '\$\(|`' "$repo/zsh/.zshenv"; then
  fail ".zshenv contains command substitution"
fi

if [ -n "$tmux_bin" ]; then
  echo "check-runtime: tmux without restored plugins"
  git_stub=$test_home/bin/git
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\\n" "$0 $*" >> "$DOTFILES_RUNTIME_LOG"' \
    'exit 97' > "$git_stub"
  chmod +x "$git_stub"
  : > "$runtime_log"
  env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C \
    DOTFILES_RUNTIME_LOG="$runtime_log" \
    "$tmux_bin" -S "$tmux_missing_socket" -f "$test_home/.tmux.conf" \
      new-session -d 'sleep 30' || fail "tmux failed without plugins"
  tpm_state=$(env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C \
    "$tmux_bin" -S "$tmux_missing_socket" show-option -gv @dotfiles_tpm) || \
    fail "tmux did not expose the missing-plugin state"
  [ "$tpm_state" = missing ] || fail "tmux did not mark TPM as missing"
  [ ! -d "$test_home/.tmux/plugins" ] || \
    fail "tmux startup created a plugin directory"
  [ ! -s "$runtime_log" ] || fail "tmux startup invoked git"
  env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C \
    "$tmux_bin" -S "$tmux_missing_socket" kill-server

  echo "check-runtime: tmux with restored TPM"
  fake_tpm=$test_home/.tmux/plugins/tpm/tpm
  tmux_marker=$test_root/tmux-plugin.marker
  mkdir -p "$(dirname "$fake_tpm")"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$DOTFILES_TMUX_MARKER"' > "$fake_tpm"
  chmod +x "$fake_tpm"
  : > "$runtime_log"
  env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C \
    DOTFILES_RUNTIME_LOG="$runtime_log" DOTFILES_TMUX_MARKER="$tmux_marker" \
    "$tmux_bin" -S "$tmux_restored_socket" -f "$test_home/.tmux.conf" \
      new-session -d 'sleep 30' || fail "tmux failed with restored TPM"
  attempts=0
  while [ ! -f "$tmux_marker" ] && [ "$attempts" -lt 10 ]; do
    attempts=$((attempts + 1))
    sleep 1
  done
  [ -f "$tmux_marker" ] || fail "tmux did not run restored TPM"
  [ ! -s "$runtime_log" ] || fail "restored tmux startup invoked git"
  env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C \
    "$tmux_bin" -S "$tmux_restored_socket" kill-server
else
  echo "check-runtime: tmux not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-runtime: skipping tmux cases outside CI"
fi

echo "check-runtime: ok"
