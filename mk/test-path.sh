#!/bin/sh
set -eu
# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_init check-path
mkdir -p "$test_root/real-home/.local/share/mise/shims" "$test_root/physical" "$test_root/local-bin" "$test_root/fake-home"
shims=$test_root/real-home/.local/share/mise/shims
ln -s "$shims" "$test_root/shim-alias"
printf '%s\n' '#!/bin/sh' 'echo stale-shim >&2; exit 99' > "$shims/fzf"
cp "$shims/fzf" "$shims/rg"
printf '%s\n' '#!/bin/sh' 'echo physical-fzf' > "$test_root/physical/fzf"
printf '%s\n' '#!/bin/sh' 'echo local-command' > "$test_root/local-bin/fixture"
cat > "$test_root/mise" <<'EOF'
#!/bin/sh
[ "$HOME" = "$DOTFILES_REAL_TEST_HOME" ] || exit 98
[ "$MISE_OFFLINE" = 1 ] && [ "$MISE_AUTO_INSTALL" = false ] || exit 97
[ "$1 $2" = 'which fzf' ] || exit 1
printf '%s/physical/fzf\n' "$DOTFILES_PATH_TEST_ROOT"
EOF
chmod +x "$shims/fzf" "$shims/rg" "$test_root/physical/fzf" "$test_root/local-bin/fixture" "$test_root/mise"
(
  unset DOTFILES_TEST_PATH_READY
  export HOME="$test_root/real-home" MISE_SHIMS_DIR="$test_root/shim-alias" MISE_BIN="$test_root/mise" MISE_ENV=real-session
  export DOTFILES_REAL_TEST_HOME="$HOME" DOTFILES_PATH_TEST_ROOT="$test_root"
  PATH="$test_root/shim-alias:$shims:$test_root/local-bin:/usr/bin:/bin"
  export PATH
  test_prepare_path
  export HOME="$test_root/fake-home"
  [ "$(fzf)" = physical-fzf ] || fail "did not use a physical mise binary under scratch HOME"
  [ "$(fixture)" = local-command ] || fail "removed user-space commands"
  [ "${MISE_ENV+x}" != x ] && [ "${MISE_SHIMS_DIR+x}" != x ] || fail "kept real mise environment"
  case $PATH in *"$shims"*|*"$test_root/shim-alias"*) fail "kept original or aliased shims" ;; esac
  [ "$(command -v rg 2>/dev/null || true)" != "$shims/rg" ] || fail "unresolved shim survived"
)
echo 'check-path: ok'
