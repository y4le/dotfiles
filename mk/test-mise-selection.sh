#!/bin/sh

set -eu
repo=$(CDPATH='' cd -P -- "${0%/*}/.." && pwd -P)
# shellcheck source=mk/test-lib.sh
. "$repo/mk/test-lib.sh"
test_init check-mise-selection
catalog=$repo/setup/tools.toml
home=$test_root/home
mkdir -p "$home"
lite=$(sh "$repo/mk/profile.sh" tools lite '')
select_config() {
  sh "$repo/mk/select-mise.sh" "$1" "$repo" "$home" "$catalog" "${2:-$lite}"
}
target=$home/.config/mise/conf.d/dotfiles.toml

echo 'check-mise-selection: offline preview, atomic rendering and idempotency'
select_config --plan > "$test_root/plan"
[ ! -e "$home/.config" ] || fail 'preview changed HOME'
grep -Fq 'aqua:junegunn/fzf' "$test_root/plan" || fail 'preview omitted selected pins'
select_config --apply >/dev/null
[ -f "$target" ] && [ ! -L "$target" ] || fail 'fragment is not a regular file'
[ "$(head -n 1 "$target")" = "# dotfiles mise selection: $repo" ] || fail 'ownership marker is wrong'
[ "$(awk -v action=keys -f "$repo/mk/catalog.awk" "$target")" = "$lite" ] || fail 'selection leaked tools'
before=$(ls -i "$target")
select_config --apply >/dev/null
[ "$before" = "$(ls -i "$target")" ] || fail 'idempotent apply replaced the file'
cp "$target" "$test_root/before"
if select_config --apply unknown-tool > "$test_root/invalid" 2>&1; then
  fail 'unknown selected key was accepted'
fi
cmp -s "$target" "$test_root/before" || fail 'failed render changed the previous fragment'
for tmp in "${target%/*}"/.dotfiles.*; do
  [ ! -e "$tmp" ] || fail 'render leaked an in-progress fragment'
done
select_config --apply 'node rust' >/dev/null
rust_entry=$(sed -n '/^rust = /p' "$catalog")
[ -n "$rust_entry" ] || fail 'Rust catalog entry is missing'
grep -Fxq "$rust_entry" "$target" || \
  fail 'projection lost inline tool options'
select_config --clean >/dev/null
[ ! -e "$target" ] || fail 'clean left an owned fragment'

echo 'check-mise-selection: foreign files, symlinks and other checkouts are preserved'
for foreign in unmarked other-checkout; do
  case $foreign in
    unmarked) printf '# user config\n[tools]\nnode = "22"\n' > "$target" ;;
    other-checkout) printf '# dotfiles mise selection: /other/checkout\n[tools]\n' > "$target" ;;
  esac
  cp "$target" "$test_root/foreign"
  for mode in --check --plan --apply; do
    if select_config "$mode" >/dev/null 2>&1; then fail "$mode accepted $foreign fragment"; fi
  done
  select_config --clean >/dev/null
  cmp -s "$target" "$test_root/foreign" || fail 'foreign fragment was modified'
  rm "$target"
done
printf '# private file\n' > "$test_root/private"
ln -s "$test_root/private" "$target"
if select_config --apply >/dev/null 2>&1; then fail 'symlink fragment was accepted'; fi
select_config --clean >/dev/null
[ -L "$target" ] || fail 'clean removed a foreign symlink'
[ "$(cat "$test_root/private")" = '# private file' ] || fail 'symlink target was changed'
rm "$target"
rmdir "${target%/*}"
ln -s "$test_root" "${target%/*}"
if select_config --apply >/dev/null 2>&1; then fail 'symlink parent was accepted'; fi
[ ! -e "$test_root/dotfiles.toml" ] || fail 'render escaped through a symlink parent'
rm "${target%/*}"
mkdir -p "${target%/*}"

echo 'check-mise-selection: preflight stops setup before installers run'
printf '# user config\n' > "$target"
real_make=$(command -v make)
cat > "$test_root/make-spy" <<'EOF'
#!/bin/sh
if [ "$1" = _mise-preflight ]; then
  exec "$DOTFILES_REAL_MAKE" -s -C "$DOTFILES_TEST_REPO" PROFILE=full WITH= _mise-preflight
fi
printf '%s\n' "$*" >> "$DOTFILES_INSTALL_LOG"
exit 89
EOF
chmod +x "$test_root/make-spy"
if HOME="$home" DOTFILES_REAL_MAKE="$real_make" DOTFILES_TEST_REPO="$repo" \
  DOTFILES_INSTALL_LOG="$test_root/install.log" make -s -C "$repo" PROFILE=full WITH= \
  MAKE="$test_root/make-spy" setup-user > "$test_root/setup.log" 2>&1; then
  fail 'setup accepted a foreign fragment'
fi
grep -Fq 'refusing foreign file' "$test_root/setup.log" || fail 'setup failed for an unrelated reason'
[ ! -e "$test_root/install.log" ] || fail 'setup ran an installer before conflict preflight'
rm "$target"

real_mise=${DOTFILES_TEST_MISE:-$HOME/.local/bin/mise}
if ! DOTFILES_PINS_FILE="$repo/setup/pins/downloads.txt" sh "$repo/mk/pinned.sh" status mise "$real_mise" >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail 'pinned mise required in CI'
  echo 'check-mise-selection: pinned mise unavailable; skipping real resolution'
  exit 0
fi
resolve_node() (
  cd "$home"
  env -i HOME="$home" PATH=/usr/bin:/bin MISE_OFFLINE=1 \
    MISE_DATA_DIR="$test_root/data" MISE_CACHE_DIR="$test_root/cache" \
    MISE_STATE_DIR="$test_root/state" MISE_CEILING_PATHS="$home" \
    "$real_mise" ls --current --json node
)
echo 'check-mise-selection: prepared and skipped-preparation global-pin upgrades'
legacy=$test_root/legacy.toml
cp "$catalog" "$legacy"
ln -s "$legacy" "$home/.config/mise/config.toml"
select_config --apply >/dev/null
resolve_node | grep -q 'requested_version' || fail 'preparation changed existing global activation'
printf '[settings]\nauto_install = false\n' > "$legacy"
[ "$(resolve_node)" = '[]' ] || fail 'unselected Node remained active after cutover'
select_config --clean >/dev/null
[ "$(resolve_node)" = '[]' ] || fail 'skipped preparation fixture retained a Node pin'
full=$(sh "$repo/mk/profile.sh" tools full '')
select_config --apply "$full" >/dev/null
node_version=$(sed -n 's/^node = "\([^"]*\)"/\1/p' "$catalog")
[ -n "$node_version" ] || fail 'Node catalog pin is missing'
resolve_node | grep -Fq "\"requested_version\": \"$node_version\"" || fail 'full did not activate pinned Node'
[ "$(awk -v action=keys -f "$repo/mk/catalog.awk" "$target")" = "$full" ] || fail 'new full projection differs from membership'
select_config --apply "$(sh "$repo/mk/profile.sh" tools lite node)" >/dev/null
resolve_node | grep -q '"requested_version":' || fail 'standalone Node opt-in did not activate'
select_config --apply "$lite" >/dev/null
[ "$(resolve_node)" = '[]' ] || fail 'lite without Node retained the pin'
select_config --apply 'node rust' >/dev/null
resolve_node | grep -q 'requested_version' || fail 'offline application did not repair skipped preparation'
printf '[tools]\nnode = "22.16.0"\n' > "$home/.config/mise/config.local.toml"
resolve_node | grep -q '"requested_version": "22.16.0"' || fail 'local override did not win'

echo 'check-mise-selection: ok'
