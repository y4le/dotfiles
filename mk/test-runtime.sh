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
tmux_test_socket=/tmp/dotfiles-tmux-test.$$
cleanup() {
  if [ -n "$tmux_bin" ]; then
    "$tmux_bin" -S "$tmux_test_socket" kill-server >/dev/null 2>&1 || true
  fi
  rm -f "$tmux_test_socket"
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

mkdir -p "$test_home/.config/zsh/sources" "$test_home/.config/zsh/hooks"
printf '%s\n' 'typeset -g DOTFILES_ENV_MARKER=new' \
  'typeset -g DOTFILES_HOOK_ORDER=env' > \
  "$test_home/.config/zsh/hooks/env.zsh"
printf '%s\n' 'typeset -g DOTFILES_PRE_MARKER=new' \
  'typeset -g DOTFILES_ENV_BEFORE_PRE=$DOTFILES_ENV_MARKER' \
  'typeset -g DOTFILES_HOOK_ORDER=pre' > \
  "$test_home/.config/zsh/hooks/pre.zsh"
printf '%s\n' 'typeset -g DOTFILES_SOURCE_MARKER=loaded' \
  'typeset -g DOTFILES_PRE_BEFORE_SOURCE=$DOTFILES_PRE_MARKER' \
  'typeset -g DOTFILES_HOOK_ORDER=sources' > \
  "$test_home/.config/zsh/sources/runtime-test.zsh"
printf '%s\n' 'typeset -g DOTFILES_POST_MARKER=new' \
  'typeset -g DOTFILES_HOOK_ORDER=post' > \
  "$test_home/.config/zsh/hooks/post.zsh"

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
    TMUX="${DOTFILES_TEST_TMUX:-}" \
    DOTFILES_RUNTIME_LOG="$runtime_log" \
    HTTPS_PROXY=http://127.0.0.1:9 \
    HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 \
    zsh "$@"
}

echo "check-runtime: zsh without restored plugins"
if ! run_zsh -i -c \
  'print -r -- "$HISTFILE|$NPM_GLOBALS|$DOTFILES_SOURCE_MARKER|$DOTFILES_ENV_MARKER|$DOTFILES_ENV_BEFORE_PRE|$DOTFILES_PRE_MARKER|$DOTFILES_PRE_BEFORE_SOURCE|$DOTFILES_POST_MARKER|$DOTFILES_HOOK_ORDER"' \
  > "$test_root/no-cache.out" 2> "$test_root/no-cache.err"; then
  fail "interactive zsh failed without optional tools"
fi
[ "$(cat "$test_root/no-cache.out")" = \
  "$test_home/.local/state/zsh/history|$test_home/.local/share/npm|loaded|new|new|new|new|new|post" ] || \
  fail "interactive zsh skipped normal configuration"
noninteractive_hook_state=$(run_zsh -c \
  'print -r -- "$DOTFILES_ENV_MARKER|${DOTFILES_PRE_MARKER-unset}|${DOTFILES_POST_MARKER-unset}"' \
  2> "$test_root/noninteractive-hooks.err") || \
  fail "noninteractive zsh could not load its environment hook"
[ "$noninteractive_hook_state" = 'new|unset|unset' ] || \
  fail "Zsh local hooks ran in the wrong startup phase"

echo "check-runtime: Zsh legacy local hook fallback"
printf '%s\n' 'typeset -g DOTFILES_ENV_MARKER=legacy' > "$test_home/.zshenv.local"
printf '%s\n' 'typeset -g DOTFILES_PRE_MARKER=legacy' > "$test_home/.pre_profile"
printf '%s\n' 'typeset -g DOTFILES_POST_MARKER=legacy' > "$test_home/.post_profile"
hook_state=$(run_zsh -i -c \
  'print -r -- "$DOTFILES_ENV_MARKER|$DOTFILES_PRE_MARKER|$DOTFILES_POST_MARKER"' \
  2> "$test_root/new-hooks.err") || fail "Zsh could not prefer new hooks"
[ "$hook_state" = 'new|new|new' ] || fail "Zsh sourced legacy hooks before new hooks"
for name in env pre post; do
  mv "$test_home/.config/zsh/hooks/$name.zsh" "$test_root/$name.zsh"
done
hook_state=$(run_zsh -i -c \
  'print -r -- "$DOTFILES_ENV_MARKER|$DOTFILES_PRE_MARKER|$DOTFILES_POST_MARKER"' \
  2> "$test_root/legacy-hooks.err") || fail "Zsh could not load legacy hooks"
[ "$hook_state" = 'legacy|legacy|legacy' ] || \
  fail "Zsh did not preserve legacy local hooks"
for name in env pre post; do
  mv "$test_root/$name.zsh" "$test_home/.config/zsh/hooks/$name.zsh"
done
rm -f "$test_home/.zshenv.local" "$test_home/.pre_profile" \
  "$test_home/.post_profile"
helper_state=$(run_zsh -i -c \
  'print -r -- "$+functions[nav]|$+functions[y]|$+functions[cpy]|$+functions[fzf_src]"' \
  2> "$test_root/helpers.err") || fail "interactive zsh could not load shell helpers"
[ "$helper_state" = '1|1|1|0' ] || \
  fail "interactive zsh skipped shell helpers"
echo 'check-runtime: successful-history widget'
cat > "$test_home/bin/atuin" <<'EOF'
#!/bin/sh
case $1 in
  init) exit 0 ;;
  search) printf 'chosen command\000' ;;
esac
EOF
cat > "$test_home/bin/fzf" <<'EOF'
#!/bin/sh
cat >/dev/null
[ "${DOTFILES_TEST_CANCEL:-}" != 1 ] || exit 1
printf 'chosen command\n'
EOF
chmod +x "$test_home/bin/atuin" "$test_home/bin/fzf"
widget_state=$(run_zsh -i -c '
  function zle() { :; }
  BUFFER=before; CURSOR=6
  atuin-success-history
  print -r -- "$BUFFER|$CURSOR"
  export DOTFILES_TEST_CANCEL=1
  BUFFER=before; CURSOR=6
  atuin-success-history
  print -r -- "$BUFFER|$CURSOR"
' 2> "$test_root/widget.err") || fail "successful-history widget errored"
[ "$widget_state" = 'chosen command|14
before|6' ] || fail "successful-history widget lost selection or changed a cancellation"
fzf_opts=$(run_zsh -i -c 'print -r -- "$FZF_CTRL_T_OPTS"' 2> "$test_root/fzf-opts.err") || \
  fail "could not read Ctrl-T options"
case $fzf_opts in
  *--read0*ctrl-l:*ctrl-f:*) : ;;
  *) fail "Ctrl-T lost NUL mode or file preview bindings" ;;
esac
env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" TERM=xterm \
  bash -c '. "$HOME/.config/shell/functions/cpst"; declare -F cpy pst >/dev/null' || \
  fail "Bash could not load clipboard helpers"
env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" TERM=xterm \
  bash -c 'root_file=.; hidden=false; color=false; debug=false; . "$HOME/.config/shell/functions/fzf_sources"; declare -F fzf_src >/dev/null' || \
  fail "Bash could not load file-search helpers"
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
for command_name in bat delta mise tmux; do
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

echo "check-runtime: mise Rust shims stay ahead of cargo tools"
mkdir -p "$test_home/.local/share/mise/shims" "$test_home/.cargo/bin"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_home/.local/share/mise/shims/cargo"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_home/.cargo/bin/cargo"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_home/.cargo/bin/cargo-tool"
chmod +x "$test_home/.local/share/mise/shims/cargo" \
  "$test_home/.cargo/bin/cargo" "$test_home/.cargo/bin/cargo-tool"
printf '%s\n' 'path=("$HOME/.cargo/bin" $path)' > "$test_home/.cargo/env"
cargo_paths=$(run_zsh -c 'print -r -- "$commands[cargo]|$commands[cargo-tool]"') || \
  fail "could not inspect Rust tool path order"
[ "$cargo_paths" = \
  "$test_home/.local/share/mise/shims/cargo|$test_home/.cargo/bin/cargo-tool" ] || \
  fail "cargo env overrode pinned Rust or hid cargo-installed tools"

echo "check-runtime: macOS login restores user tool precedence"
printf '%s\n' 'typeset -g LOCAL_PROFILE_MARKER=loaded' > "$test_home/.zprofile.local"
profile_paths=$(env -i HOME="$test_home" PATH=/usr/bin:/bin \
  DOTFILES_REPO="$repo" zsh -f -c '
    path=(/usr/bin /bin)
    source "$DOTFILES_REPO/osx/.zprofile"
    print -r -- "$path[1]|$path[2]|$path[3]|$path[4]|$LOCAL_PROFILE_MARKER"
  ') || fail "macOS login profile failed"
[ "$profile_paths" = \
  "$test_home/bin|$test_home/.local/bin|$test_home/.local/share/mise/shims|/opt/homebrew/bin|loaded" ] || \
  fail "macOS login profile lost user tools or existing profile"

echo "check-runtime: interactive startup uses command presence without probes"
: > "$runtime_log"
startup_state=$(DOTFILES_TEST_PATH_PREFIX="$test_home/bin:" \
  DOTFILES_TEST_TMUX=stub-session run_zsh -i -c \
  'print -r -- "$MANPAGER|$GIT_PAGER|$MANROFFOPT|$ATUIN_TMUX_POPUP"' \
  2> "$test_root/startup-probes.err") || fail "interactive zsh failed with available tools"
[ "$startup_state" = 'bat -plman||-c|true' ] || \
  fail "interactive zsh ignored available bat or tmux, or overrode Git's pager"
if grep -Eq '/(bat|delta|mise|tmux) ' "$runtime_log"; then
  fail "interactive startup ran a version, mise or tmux capability probe"
fi
cat > "$test_home/bin/fzf-tmux" <<'EOF'
#!/bin/sh
printf '%s\n' 'fzf-tmux invoked' >> "$DOTFILES_RUNTIME_LOG"
exit 97
EOF
chmod +x "$test_home/bin/fzf-tmux"
widget_state=$(DOTFILES_TEST_PATH_PREFIX="$test_home/bin:" \
  DOTFILES_TEST_TMUX=stub-session run_zsh -i -c '
  function zle() { :; }
  BUFFER=before; CURSOR=6
  atuin-success-history
  print -r -- "$BUFFER|$CURSOR"
'  2> "$test_root/legacy-tmux-widget.err") || \
  fail "successful-history widget failed without tmux popup support"
[ "$widget_state" = 'chosen command|14' ] || \
  fail "successful-history widget did not fall back to fzf"
if grep -Fq 'fzf-tmux invoked' "$runtime_log"; then
  fail "successful-history widget used unsupported tmux popup"
fi

echo "check-runtime: prompt redraw reuses git status"
cat > "$test_home/bin/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DOTFILES_RUNTIME_LOG"
case $1 in
  rev-parse)
    case $PWD in
      */other) printf '%s\n' other-branch ;;
      *) printf '%s\n' review-branch ;;
    esac
    ;;
  status) printf '%s\n' ' M tracked' ;;
esac
EOF
chmod +x "$test_home/bin/git"
for command_name in sed basename hostname; do
  stub=$test_home/bin/$command_name
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s %s\n" "${0##*/}" "$*" >> "$DOTFILES_RUNTIME_LOG"' \
    'exit 97' > "$stub"
  chmod +x "$stub"
done
mkdir -p "$test_home/other"
: > "$runtime_log"
prompt_state=$(DOTFILES_TEST_PATH_PREFIX="$test_home/bin:" run_zsh -i -c '
  source "$HOME/.config/zsh/themes/minimal.zsh-theme"
  _mnml_git_precmd
  mnml_git; mnml_git
  cd "$HOME/other"
  mnml_git
  VIRTUAL_ENV=/tmp/project.env; SSH_TTY=/dev/tty
  mnml_status; mnml_jobs; mnml_pyenv; mnml_ssh
'  2> "$test_root/prompt.err") || fail "prompt components failed"
case $prompt_state in
  *review-branch*review-branch*other-branch*project* ) : ;;
  *) fail "prompt did not refresh the branch on cd or retain the environment" ;;
esac
[ "$(grep -Ec '^(rev-parse|status)' "$runtime_log")" -eq 4 ] || \
  fail "prompt did not refresh exactly once per directory change"
if grep -Eq '^(sed|basename|hostname) ' "$runtime_log"; then
  fail "prompt component spawned a basic command"
fi
for command_name in sed basename hostname; do
  rm "$test_home/bin/$command_name"
done

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
  echo "check-runtime: tmux configuration"
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
    "$tmux_bin" -S "$tmux_test_socket" \
      new-session -d 'sleep 30' || fail "tmux failed with the minimal configuration"

  run_tmux() {
    env -i HOME="$test_home" PATH="/usr/local/bin:/usr/bin:/bin" \
      SHELL=/bin/sh TERM=xterm LC_ALL=C \
      "$tmux_bin" -S "$tmux_test_socket" "$@"
  }
  assert_tmux_value() {
    description=$1
    expected=$2
    shift 2
    actual=$(run_tmux "$@") || fail "could not read tmux $description"
    [ "$actual" = "$expected" ] || \
      fail "tmux $description: expected $expected, got $actual"
  }

  assert_tmux_value history-limit 50000 show-option -gv history-limit
  assert_tmux_value focus-events on show-option -sv focus-events
  assert_tmux_value escape-time 0 show-option -sv escape-time
  assert_tmux_value display-time 4000 show-option -gv display-time
  assert_tmux_value status-interval 5 show-option -gv status-interval
  assert_tmux_value status-keys emacs show-option -gv status-keys
  assert_tmux_value mode-keys vi show-window-option -gv mode-keys
  assert_tmux_value mouse on show-option -gv mouse
  assert_tmux_value base-index 1 show-option -gv base-index
  assert_tmux_value default-terminal screen-256color show-option -gv default-terminal
  assert_tmux_value allow-passthrough on show-option -gv allow-passthrough
  assert_tmux_value set-clipboard on show-option -gv set-clipboard
  assert_tmux_value prefix C-b show-option -gv prefix
  assert_tmux_value prefix-format C-b display-message -p '#{prefix}'

  run_tmux list-keys -T copy-mode-vi y | grep -q 'copy-pipe-and-cancel cpy' || \
    fail "tmux copy-mode y does not copy through cpy"
  run_tmux list-keys -T copy-mode-vi v | grep -q 'begin-selection' || \
    fail "tmux copy-mode v does not begin selection"
  run_tmux list-keys -T copy-mode-vi V | grep -q 'rectangle-toggle' || \
    fail "tmux copy-mode V does not toggle rectangular selection"
  run_tmux list-keys -T root C-h | grep -q 'select-pane -L' || \
    fail "tmux navigation does not move left across panes"
  run_tmux list-keys -T root C-l | grep -q 'select-pane -R' || \
    fail "tmux navigation does not move right across panes"
  if run_tmux list-keys | grep -q 'plugins/'; then
    fail "tmux still has plugin-backed key bindings"
  fi
  if run_tmux show-options -g | grep -Eq '^@(plugin|resurrect|continuum|dotfiles_tpm)'; then
    fail "tmux still exposes plugin options"
  fi
  case $(run_tmux show-option -gv status-right) in
    *'#('* ) fail "tmux status bar still runs a plugin command" ;;
  esac
  case $(run_tmux show-option -gv status-left) in
    *'#{prefix}'*'#{client_key_table}'*) ;;
    *) fail "tmux status bar does not show prefix and resize state" ;;
  esac
  case $(run_tmux show-option -gv status-right) in
    *'%S'*) ;;
    *) fail "tmux status bar does not show its clock" ;;
  esac

  run_tmux source-file "$test_home/.config/tmux/prefix_a.tmux.conf"
  assert_tmux_value prefix C-a show-option -gv prefix
  assert_tmux_value prefix-format C-a display-message -p '#{prefix}'
  run_tmux list-keys -T prefix a | grep -q 'send-prefix' || \
    fail "tmux Ctrl-A prefix cannot be sent to an inner multiplexer"
  run_tmux source-file "$test_home/.config/tmux/prefix_space.tmux.conf"
  assert_tmux_value prefix C-Space show-option -gv prefix
  assert_tmux_value prefix-format C-Space display-message -p '#{prefix}'
  run_tmux list-keys -T prefix Space | grep -q 'send-prefix' || \
    fail "tmux Ctrl-Space prefix cannot be sent to an inner multiplexer"
  run_tmux source-file "$test_home/.config/tmux/prefix_b.tmux.conf"
  assert_tmux_value prefix C-b show-option -gv prefix
  assert_tmux_value prefix-format C-b display-message -p '#{prefix}'
  run_tmux list-keys -T prefix b | grep -q 'send-prefix' || \
    fail "tmux Ctrl-B prefix cannot be sent to an inner multiplexer"

  run_tmux list-keys -T prefix r | grep -q 'switch-client -T resize' || \
    fail "tmux prefix-r did not enter resize mode"
  for binding in 'h resize-pane -L 5' 'H resize-pane -L 25' \
    'j resize-pane -D 5' 'J resize-pane -D 25' \
    'k resize-pane -U 5' 'K resize-pane -U 25' \
    'l resize-pane -R 5' 'L resize-pane -R 25' \
    '= select-layout tiled' '% select-layout even-horizontal' \
    '" select-layout even-vertical' 'f select-layout main-vertical'; do
    key=${binding%% *}
    action=${binding#* }
    run_tmux list-keys -T resize "$key" | grep -Fq "$action" || \
      fail "tmux resize mode lost $key action"
    run_tmux list-keys -T resize "$key" | grep -Fq 'switch-client -T resize' || \
      fail "tmux resize mode exits after $key"
  done
  for key in Escape q; do
    run_tmux list-keys -T resize "$key" | grep -Fq 'switch-client -T root' || \
      fail "tmux resize mode cannot exit with $key"
  done
  run_tmux bind-key -n h resize-pane -L 5
  run_tmux source-file "$test_home/.config/tmux/tmux.conf"
  if run_tmux list-keys -T root h >/dev/null 2>&1; then
    fail "tmux reload left the old root h binding active"
  fi

  [ ! -s "$runtime_log" ] || fail "tmux startup invoked git"
  run_tmux kill-server
else
  echo "check-runtime: tmux not found"
  if [ -n "${CI:-}" ]; then
    exit 1
  fi
  echo "check-runtime: skipping tmux cases outside CI"
fi

echo "check-runtime: ok"
