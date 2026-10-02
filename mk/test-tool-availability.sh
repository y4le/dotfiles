#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
repo=$(CDPATH='' cd -P -- "${0%/*}/.." && pwd -P)
test_init check-tool-availability
original_home=$HOME
original_data=${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}
home=$test_root/home
shims=$test_root/shims
system=$test_root/system
mkdir -p "$home/.local/bin" "$shims" "$system" "$test_root/active"
cat > "$home/.local/bin/mise" <<'EOF'
#!/bin/sh
[ "$MISE_OFFLINE" = 1 ] && [ "$MISE_AUTO_INSTALL" = false ] || exit 99
[ "$1" = which ] || exit 98
printf '%s\n' "$2" >> "$DOTFILES_PROBE_LOG"
[ "$DOTFILES_TOOL_ACTIVE" = yes ] || exit 1
printf '%s/%s\n' "$DOTFILES_ACTIVE_BIN" "$2"
EOF
for name in nvim typescript-language-server ruff rustfmt; do
  printf '#!/bin/sh\nexit 97\n' > "$shims/$name"
  printf '#!/bin/sh\nexit 0\n' > "$test_root/active/$name"
  chmod +x "$shims/$name" "$test_root/active/$name"
done
for name in nvim vim; do
  printf '#!/bin/sh\nprintf "%s\\n"\nprintf "<%%s>\\n" "$@"\n' "$name" > "$system/$name"
  chmod +x "$system/$name"
done
chmod +x "$home/.local/bin/mise"
export HOME="$home" MISE_SHIMS_DIR="$shims" DOTFILES_ACTIVE_BIN="$test_root/active"
export DOTFILES_PROBE_LOG="$test_root/probes" DOTFILES_TOOL_ACTIVE=no
resolver=$repo/scripts/.local/bin/dotfiles-tool
launcher=$repo/scripts/.local/bin/dotfiles-vim

echo 'check-tool-availability: ordinary commands do not probe mise'
selected=$(PATH="$system:/usr/bin:/bin" "$resolver" nvim)
[ "$selected" = "$system/nvim" ] || fail 'ordinary Neovim was not preferred'
[ ! -e "$DOTFILES_PROBE_LOG" ] || fail 'ordinary lookup probed mise'

echo 'check-tool-availability: stale shims fall through, active shims keep backend env'
selected=$(PATH="$shims:$system:/usr/bin:/bin" "$resolver" nvim)
[ "$selected" = "$system/nvim" ] || fail 'stale shim hid system Neovim'
selected=$(DOTFILES_TOOL_ACTIVE=yes PATH="$shims:$system:/usr/bin:/bin" "$resolver" nvim)
[ "$selected" = "$shims/nvim" ] || fail 'active shim was bypassed'
ln -s "$shims" "$test_root/shim-alias"
selected=$(PATH="$test_root/shim-alias:$system:/usr/bin:/bin" "$resolver" nvim)
[ "$selected" = "$system/nvim" ] || fail 'aliased shim directory bypassed availability check'
if PATH="$shims:/usr/bin:/bin" "$resolver" typescript-language-server >/dev/null 2>&1; then
  fail 'unconfigured language-server shim was treated as usable'
fi

echo 'check-tool-availability: launcher selects Vim and forwards arguments literally'
rm "$system/nvim"
actual=$(PATH="$shims:$system:/usr/bin:/bin" "$launcher" '+42' 'path with spaces' 'literal $(touch should-not-exist)')
expected=$(printf 'vim\n<+42>\n<path with spaces>\n<literal $(touch should-not-exist)>')
[ "$actual" = "$expected" ] || fail 'Vim fallback or argument forwarding failed'
[ ! -e should-not-exist ] || fail 'launcher evaluated filename text'
if PATH="$shims:$test_root/active" "$resolver" missing >/dev/null 2>&1; then
  fail 'missing command was accepted'
fi
# Empty and trailing PATH elements represent the current directory.
selected=$(cd "$system" && PATH='' "$resolver" vim)
[ "$selected" = "$system/vim" ] || fail 'empty PATH element was lost'
selected=$(cd "$system" && PATH="$test_root/active:" "$resolver" vim)
[ "$selected" = "$system/vim" ] || fail 'trailing PATH element was lost'

nvim_bin=${DOTFILES_TEST_NVIM:-}
if [ -n "$nvim_bin" ]; then
  echo 'check-tool-availability: Neovim skips stale LSP, linter and formatter shims'
  DOTFILES_REPO="$repo" DOTFILES_TEST_SHIMS="$shims" DOTFILES_TEST_SYSTEM="$system" \
    DOTFILES_TEST_RESOLVER="$resolver" PATH="$shims:$system:$repo/scripts/.local/bin:/usr/bin:/bin" \
    "$nvim_bin" --headless -u NONE -i NONE -n -l "$repo/mk/test-tool-availability.lua"
fi

real_mise=${DOTFILES_TEST_MISE:-$original_home/.local/bin/mise}
if [ -n "$nvim_bin" ] && DOTFILES_PINS_FILE="$repo/setup/pins/downloads.txt" \
  sh "$repo/mk/pinned.sh" status mise "$real_mise" >/dev/null 2>&1; then
  echo 'check-tool-availability: real mise honours project and local activation'
  mkdir -p "$home/.config/mise" "$test_root/project"
  printf '[settings]\nauto_install = false\nexec_auto_install = false\n' > "$home/.config/mise/config.toml"
  rm "$shims/nvim"
  ln -s "$real_mise" "$shims/nvim"
  nvim_version=$(sed -n 's/^"aqua:neovim\/neovim" = "\([^"]*\)"/\1/p' "$repo/setup/tools.toml")
  real_resolve() (
    cd "$1"
    env -i HOME="$home" PATH="$shims:$system:/usr/bin:/bin" \
      MISE_BIN="$real_mise" MISE_SHIMS_DIR="$shims" MISE_DATA_DIR="$original_data" \
      MISE_CACHE_DIR="$test_root/real-cache" MISE_STATE_DIR="$test_root/real-state" \
      MISE_CEILING_PATHS="$test_root" MISE_TRUSTED_CONFIG_PATHS="$test_root" \
      MISE_OFFLINE=1 "$resolver" nvim
  )
  if real_resolve "$test_root/project" >/dev/null 2>&1; then
    fail 'installed but unconfigured real mise Neovim was accepted'
  fi
  printf '[tools]\n"aqua:neovim/neovim" = "%s"\n' "$nvim_version" > "$test_root/project/mise.toml"
  [ "$(real_resolve "$test_root/project")" = "$shims/nvim" ] || fail 'project override was not eligible'
  cp "$test_root/project/mise.toml" "$home/.config/mise/config.local.toml"
  [ "$(real_resolve "$home")" = "$shims/nvim" ] || fail 'machine-local override was not eligible'
fi

echo 'check-tool-availability: ok'
