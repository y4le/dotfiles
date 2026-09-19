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
original_home=$HOME
tmux_bin=$(command -v tmux 2>/dev/null || true)
nvim_bin=$(command -v nvim 2>/dev/null || true)
if command -v mise >/dev/null 2>&1; then
  mise_nvim=$(MISE_GLOBAL_CONFIG_FILE="$(pwd -P)/mise/.config/mise/config.toml" \
    mise which nvim 2>/dev/null || true)
  if [ -x "$mise_nvim" ]; then
    nvim_bin=$mise_nvim
  fi
fi
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
stow -R --no-folding -d "$repo" -t "$test_home" zsh scripts tmux nvim >/dev/null 2>&1 || \
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

run_zsh_xdg() (
  test_xdg_data=$1
  test_xdg_state=$2
  shift 2
  env -i \
    HOME="$test_home" \
    PATH="${DOTFILES_TEST_PATH_PREFIX:-}/usr/local/bin:/usr/bin:/bin" \
    XDG_DATA_HOME="$test_xdg_data" \
    XDG_STATE_HOME="$test_xdg_state" \
    SHELL=/bin/sh \
    TERM=dumb \
    LC_ALL=C \
    DOTFILES_RUNTIME_LOG="$runtime_log" \
    HTTPS_PROXY=http://127.0.0.1:9 \
    HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 \
    zsh "$@"
)

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
  'print -r -- "$HISTFILE|$NPM_GLOBALS|$DOTFILES_SOURCE_MARKER|$DOTFILES_POST_MARKER"' \
  > "$test_root/no-cache.out" 2> "$test_root/no-cache.err"; then
  fail "interactive zsh failed without optional tools"
fi
[ "$(cat "$test_root/no-cache.out")" = \
  "$test_home/.local/state/zsh/history|$test_home/.local/share/npm|loaded|loaded" ] || \
  fail "interactive zsh skipped normal configuration"
[ -d "$test_home/.local/state/zsh" ] || \
  fail "interactive zsh did not create its state directory"
[ "$(grep -Fc "dotfiles: zsh plugins not restored; run 'make plugins'" \
  "$test_root/no-cache.err")" -eq 1 ] || \
  fail "interactive zsh did not print exactly one restore hint"
[ ! -s "$runtime_log" ] || fail "zsh startup invoked a network-capable command"

echo "check-runtime: zsh XDG overrides"
xdg_data=$test_root/xdg-data
xdg_state=$test_root/xdg-state
if ! run_zsh_xdg "$xdg_data" "$xdg_state" -i -c \
  'print -r -- "$HISTFILE|$NPM_GLOBALS"' \
  > "$test_root/xdg.out" 2> "$test_root/xdg.err"; then
  fail "interactive zsh failed with XDG overrides"
fi
[ "$(cat "$test_root/xdg.out")" = \
  "$xdg_state/zsh/history|$xdg_data/npm" ] || \
  fail "interactive zsh ignored XDG data or state overrides"
[ -d "$xdg_state/zsh" ] || fail "zsh did not create the overridden state path"

echo "check-runtime: zsh state fallback"
blocked_state=$test_root/blocked-state
: > "$blocked_state"
if ! run_zsh_xdg "$xdg_data" "$blocked_state" -i -c \
  'print -r -- "$HISTFILE"' \
  > "$test_root/state-fallback.out" 2> "$test_root/state-fallback.err"; then
  fail "interactive zsh failed when its state path was unavailable"
fi
[ "$(cat "$test_root/state-fallback.out")" = "$test_home/.history" ] || \
  fail "zsh did not fall back to its legacy history path"
grep -F "dotfiles: could not create $blocked_state/zsh; using ~/.history" \
  "$test_root/state-fallback.err" >/dev/null || \
  fail "zsh did not report its history fallback"

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

if [ -n "$nvim_bin" ]; then
  git_stub=$test_home/bin/git
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\\n" "$0 $*" >> "$DOTFILES_RUNTIME_LOG"' \
    'exit 97' > "$git_stub"
  chmod +x "$git_stub"
  echo "check-runtime: Neovim without lazy.nvim"
  : > "$runtime_log"
  lock_before=$(cksum < "$repo/nvim/.config/nvim/lazy-lock.json")
  if ! env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
    SHELL=/bin/sh TERM=xterm LC_ALL=C DOTFILES_RUNTIME_LOG="$runtime_log" \
    HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 "$nvim_bin" --headless +qa \
    > "$test_root/nvim-missing.out" 2> "$test_root/nvim-missing.err"; then
    cat "$test_root/nvim-missing.out" "$test_root/nvim-missing.err" >&2
    fail "Neovim failed without lazy.nvim"
  fi
  cat "$test_root/nvim-missing.out" "$test_root/nvim-missing.err" > \
    "$test_root/nvim-missing.log"
  grep -Fq "lazy.nvim not found - run 'make nvim-plugins'" \
    "$test_root/nvim-missing.log" || fail "Neovim omitted the missing-lazy hint"
  [ ! -s "$runtime_log" ] || fail "Neovim startup invoked git or a downloader"

  lazy_data_home=${XDG_DATA_HOME:-$original_home/.local/share}
  lazy_source=${DOTFILES_TEST_LAZY_DIR:-$lazy_data_home/nvim/lazy/lazy.nvim}
  if [ -d "$lazy_source" ]; then
    echo "check-runtime: Neovim with lazy.nvim but no restored plugins"
    lazy_dir=$test_home/.local/share/nvim/lazy/lazy.nvim
    mkdir -p "$(dirname "$lazy_dir")"
    cp -R "$lazy_source" "$lazy_dir"
    : > "$runtime_log"
    if ! env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
      SHELL=/bin/sh TERM=xterm LC_ALL=C DOTFILES_RUNTIME_LOG="$runtime_log" \
      HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
      ALL_PROXY=http://127.0.0.1:9 "$nvim_bin" --headless +qa \
      > "$test_root/nvim-unrestored.out" 2> "$test_root/nvim-unrestored.err"; then
      cat "$test_root/nvim-unrestored.out" "$test_root/nvim-unrestored.err" >&2
      fail "Neovim failed with only lazy.nvim restored"
    fi
    cat "$test_root/nvim-unrestored.out" "$test_root/nvim-unrestored.err" > \
      "$test_root/nvim-unrestored.log"
    grep -Fq "Neovim plugins not restored; run 'make plugins'" \
      "$test_root/nvim-unrestored.log" || \
      fail "Neovim omitted the plugin restore hint"
    [ ! -s "$runtime_log" ] || fail "unrestored Neovim invoked git or a downloader"

    echo "check-runtime: partial Neovim plugin state stays offline"
    mkdir -p "$test_home/.local/share/nvim/lazy/plenary.nvim"
    : > "$runtime_log"
    env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
      SHELL=/bin/sh TERM=xterm LC_ALL=C DOTFILES_RUNTIME_LOG="$runtime_log" \
      HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
      ALL_PROXY=http://127.0.0.1:9 "$nvim_bin" --headless +qa \
      > "$test_root/nvim-partial.out" 2> "$test_root/nvim-partial.err" || \
      fail "Neovim failed with a partial plugin state"
    [ ! -s "$runtime_log" ] || fail "partial Neovim startup invoked git or a downloader"
    if find "$test_home/.local/share/nvim" -name '*.cloning' -print | grep -q .; then
      fail "partial Neovim startup left clone state"
    fi
    [ "$(cksum < "$repo/nvim/.config/nvim/lazy-lock.json")" = "$lock_before" ] || \
      fail "Neovim startup changed the lockfile"

    echo "check-runtime: failed Neovim restore preserves the lock"
    rm -f "$git_stub"
    restore_lock=$test_root/lazy-lock.json
    restore_lock_before=$test_root/lazy-lock.before.json
    restore_count=$test_root/nvim-restore-count
    cp "$repo/nvim/.config/nvim/lazy-lock.json" "$restore_lock"
    cp "$restore_lock" "$restore_lock_before"
    restore_lazy_commit=$(git -C "$lazy_dir" rev-parse HEAD) || \
      fail "could not read the lazy.nvim fixture revision"
    printf '%s\n' \
      '#!/bin/sh' \
      'count=0' \
      '[ ! -f "$DOTFILES_TEST_RESTORE_COUNT" ] || count=$(cat "$DOTFILES_TEST_RESTORE_COUNT")' \
      'count=$((count + 1))' \
      'printf "%s\n" "$count" > "$DOTFILES_TEST_RESTORE_COUNT"' \
      '[ "$count" -eq 1 ] && exit 0' \
      'printf "%s\n" corrupted > "$DOTFILES_TEST_RESTORE_LOCK"' \
      'exit 42' > "$test_home/bin/nvim"
    chmod +x "$test_home/bin/nvim"
    if env -i HOME="$test_home" PATH="$test_home/bin:/usr/local/bin:/usr/bin:/bin" \
      DOTFILES_TEST_RESTORE_COUNT="$restore_count" \
      DOTFILES_TEST_RESTORE_LOCK="$restore_lock" \
      make -s -C "$repo" MISE_BIN="$test_home/missing-mise" \
        LAZY_NVIM_DIR="$lazy_dir" LAZY_NVIM_LOCK_FILE="$restore_lock" \
        LAZY_NVIM_COMMIT="$restore_lazy_commit" nvim-plugins \
        > "$test_root/nvim-restore.out" 2> "$test_root/nvim-restore.err"; then
      fail "simulated Neovim restore failure succeeded"
    fi
    cmp -s "$restore_lock_before" "$restore_lock" || \
      fail "failed Neovim restore changed the lockfile"
    if [ ! -f "$restore_count" ] || [ "$(cat "$restore_count")" -ne 2 ]; then
      fail "simulated failure did not reach the Neovim restore process"
    fi
  else
    if [ -n "${CI:-}" ]; then
      echo "check-runtime: lazy.nvim fixture is required in CI"
      exit 1
    fi
    echo "check-runtime: lazy.nvim fixture not found; skipping restored-state cases"
  fi
else
  if [ -n "${CI:-}" ]; then
    echo "check-runtime: nvim is required in CI"
    exit 1
  fi
  echo "check-runtime: nvim not found; skipping Neovim cases"
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
