#!/bin/sh
set -eu
# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path
test_init check-herdr-integrations
repo=$(CDPATH='' cd -P -- "${0%/*}/.." && pwd -P)
helper=$repo/mk/herdr-integrations.sh
mkdir -p "$test_root/home/.claude" "$test_root/home/.codex" "$test_root/bin"
for agent in claude codex; do
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$test_root/bin/$agent"
  chmod +x "$test_root/bin/$agent"
done
cat > "$test_root/bin/herdr" <<'EOF'
#!/bin/sh
if [ "$HOME" != "$DOTFILES_REAL_TEST_HOME" ]; then
  printf 'preflight %s\n' "$3" >> "$DOTFILES_INTEGRATION_LOG"
  if [ "$3" = codex ] && [ -f "$CODEX_HOME/hooks.json" ] && grep -q invalid "$CODEX_HOME/hooks.json"; then exit 93; fi
else
  printf 'install %s\n' "$3" >> "$DOTFILES_INTEGRATION_LOG"
fi
EOF
chmod +x "$test_root/bin/herdr"
run() {
  env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
    DOTFILES_REAL_TEST_HOME="$test_root/home" DOTFILES_INTEGRATION_LOG="$test_root/install.log" \
    sh "$helper" "$@"
}
[ "$(run --select "$repo" auto 2> "$test_root/auto.out")" = 'claude codex' ] || fail "auto selection included absent agy"
grep -q 'skipping.*antigravity-cli' "$test_root/auto.out" || fail "auto did not report skipped agent"
if run --select "$repo" 'claude codex antigravity-cli' > /dev/null 2>&1; then fail "accepted an absent explicit agent"; fi
[ ! -e "$test_root/install.log" ] || fail "selection wrote integrations"
for selection in '' '   ' 'claude unsupported'; do
  if run --select "$repo" "$selection" > /dev/null 2>&1; then fail "accepted invalid selection"; fi
done
mv "$test_root/home/.codex" "$test_root/codex-uninitialized"
if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted uninitialized Codex"; fi
[ "$(run --select "$repo" auto 2>/dev/null)" = claude ] || fail "auto included uninitialized Codex"
mv "$test_root/codex-uninitialized" "$test_root/home/.codex"
printf 'invalid\n' > "$test_root/home/.codex/hooks.json"
if run --install "$repo" "$test_root/bin/herdr" 'claude codex' >/dev/null 2>&1; then fail "accepted malformed later config"; fi
if grep -q '^install ' "$test_root/install.log"; then fail "modified an agent before all config preflights passed"; fi
[ "$(cat "$test_root/home/.codex/hooks.json")" = invalid ] || fail "preflight changed real config"
rm "$test_root/home/.codex/hooks.json"
: > "$test_root/install.log"
run --install "$repo" "$test_root/bin/herdr" 'claude codex' > /dev/null
[ "$(cat "$test_root/install.log")" = "$(printf 'preflight claude\npreflight codex\ninstall claude\ninstall codex')" ] || fail "did not preflight the entire selection before install"
mkdir "$test_root/home/.codex/hooks.json"
if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted a directory as config"; fi
rmdir "$test_root/home/.codex/hooks.json"
mkdir "$test_root/home/.codex/herdr-agent-state.sh"
if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted a directory as hook"; fi
rmdir "$test_root/home/.codex/herdr-agent-state.sh"
chmod 555 "$test_root/home/.codex"
if [ ! -w "$test_root/home/.codex" ]; then
  if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted read-only agent config"; fi
fi
chmod 755 "$test_root/home/.codex"
mkdir "$test_root/config-targets"
printf '{}\n' > "$test_root/config-targets/hooks.json"
ln -s "$test_root/config-targets/hooks.json" "$test_root/home/.codex/hooks.json"
ln "$test_root/config-targets/hooks.json" "$test_root/hard-linked-config"
if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted a symlink to a hard-linked config"; fi
rm "$test_root/hard-linked-config"
chmod 555 "$test_root/config-targets"
if [ ! -w "$test_root/config-targets" ]; then
  if run --select "$repo" 'claude codex' >/dev/null 2>&1; then fail "accepted config linked into a read-only directory"; fi
fi
chmod 755 "$test_root/config-targets"
run --select "$repo" 'claude codex' >/dev/null || fail "rejected config linked into a writable directory"
echo 'check-herdr-integrations: make dry runs never install or write integrations'
: > "$test_root/install.log"
env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
  DOTFILES_REAL_TEST_HOME="$test_root/home" DOTFILES_INTEGRATION_LOG="$test_root/install.log" \
  make -n -s -C "$repo" HERDR_BIN="$test_root/bin/herdr" \
  HERDR_INTEGRATIONS='claude codex' herdr-integrations > "$test_root/dry-run.out" 2>&1 || fail "dry run failed"
[ ! -s "$test_root/install.log" ] || fail "make -n installed or validated integrations"
grep -Fq 'herdr-integrations.sh --install' "$test_root/dry-run.out" || fail "dry run did not describe integration installation"
echo 'check-herdr-integrations: ok'
