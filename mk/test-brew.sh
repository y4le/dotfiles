#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

fail() {
  echo "check-brew: $*" >&2
  exit 1
}

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
test_root=$(mktemp -d) || exit 1
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

live_bin=$test_root/live-bin
dead_bin=$test_root/dead-bin
candidate_bin=$test_root/candidate/bin
danger_bin=$test_root/danger-bin
brew_log=$test_root/brew.log
danger_log=$test_root/danger.log
mkdir -p "$live_bin" "$dead_bin" "$candidate_bin" "$danger_bin"

write_live_brew() {
  destination=$1
  prefix=$2
  printf '%s\n' \
    '#!/bin/sh' \
    'if [ "${1:-}" = --prefix ]; then' \
    "  printf '%s\\n' '$prefix'" \
    '  exit 0' \
    'fi' \
    'printf "no-auto=%s %s\n" "${HOMEBREW_NO_AUTO_UPDATE:-}" "$*" >> "$DOTFILES_BREW_LOG"' \
    'exit 0' > "$destination"
  chmod +x "$destination"
}

write_live_brew "$live_bin/brew" "$test_root/live-prefix"
write_live_brew "$candidate_bin/brew" "$test_root/candidate-prefix"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$dead_bin/brew"
chmod +x "$dead_bin/brew"

for command_name in curl wget sudo installer bash; do
  # This single-quoted line is the body of the generated command stub.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s %s\n" "$0" "$*" >> "$DOTFILES_DANGER_LOG"' \
    'exit 97' > "$danger_bin/$command_name"
  chmod +x "$danger_bin/$command_name"
done

base_path=$danger_bin:/usr/bin:/bin

echo "check-brew: PATH discovery"
actual=$(env -i PATH="$live_bin:$base_path" BREW_SEARCH_PATHS= \
  sh "$repo/mk/find-brew.sh")
[ "$actual" = "$live_bin/brew" ] || fail "did not select live PATH brew"
output=$(env -i HOME="$test_root/home" PATH="$live_bin:$base_path" \
  BREW_SEARCH_PATHS= DOTFILES_DANGER_LOG="$danger_log" \
  make -s -C "$repo" PLATFORM=macos brew)
printf '%s\n' "$output" | grep -F "brew found at $live_bin/brew" >/dev/null || \
  fail "make brew did not report the PATH brew"

echo "check-brew: configured candidate discovery"
actual=$(env -i PATH="$base_path" BREW_SEARCH_PATHS="$candidate_bin/brew" \
  sh "$repo/mk/find-brew.sh")
[ "$actual" = "$candidate_bin/brew" ] || fail "did not select configured brew"
actual=$(env -i PATH="$dead_bin:$base_path" BREW_SEARCH_PATHS="$candidate_bin/brew" \
  sh "$repo/mk/find-brew.sh")
[ "$actual" = "$candidate_bin/brew" ] || fail "did not skip a dead PATH brew"

echo "check-brew: Stow next to Homebrew when PATH is not initialized"
mkdir -p "$test_root/only-sh"
ln -s /bin/sh "$test_root/only-sh/sh"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$candidate_bin/stow"
chmod +x "$candidate_bin/stow"
actual=$(env -i PATH="$test_root/only-sh" BREW_SEARCH_PATHS="$candidate_bin/brew" \
  sh "$repo/mk/find-stow.sh" macos)
[ "$actual" = "$candidate_bin/stow" ] || fail "did not find Homebrew Stow"
actual=$(env -i PATH="$test_root/only-sh" BREW_SEARCH_PATHS="$candidate_bin/brew" \
  sh "$repo/mk/find-stow.sh" linux)
[ -z "$actual" ] || fail "Linux used the Homebrew Stow fallback"

assert_missing() {
  label=$1
  path=$2
  : > "$danger_log"
  if env -i PATH="$path" BREW_SEARCH_PATHS= DOTFILES_DANGER_LOG="$danger_log" \
    sh "$repo/mk/find-brew.sh" > "$test_root/missing.out" 2>&1; then
    fail "$label succeeded"
  fi
  grep -F 'Homebrew is required' "$test_root/missing.out" >/dev/null || \
    fail "$label did not name Homebrew"
  grep -F 'docs/setup.md' "$test_root/missing.out" >/dev/null || \
    fail "$label did not name the setup guide"
  grep -F 'make setup-user' "$test_root/missing.out" >/dev/null || \
    fail "$label did not name setup-user"
  grep -Fx 'Searched: PATH' "$test_root/missing.out" >/dev/null || \
    fail "$label did not honor an empty BREW_SEARCH_PATHS"
  [ ! -s "$danger_log" ] || fail "$label ran a forbidden command"
}

echo "check-brew: actionable offline failure"
assert_missing "dead PATH brew" "$dead_bin:$base_path"
assert_missing "missing brew" "$base_path"

echo "check-brew: system package wiring"
: > "$brew_log"
: > "$danger_log"
env -i HOME="$test_root/home" PATH="$live_bin:$base_path" BREW_SEARCH_PATHS= \
  DOTFILES_BREW_LOG="$brew_log" DOTFILES_DANGER_LOG="$danger_log" \
  HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
  ALL_PROXY=http://127.0.0.1:9 \
  make -s -C "$repo" PLATFORM=macos PACKAGE_MANAGER=brew system-packages
expected_packages=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' \
  "$repo/setup/packages/brew.txt" | tr '\n' ' ' | sed 's/ $//')
[ "$(sed -n '1p' "$brew_log")" = "no-auto=1 install $expected_packages" ] || \
  fail "system-packages called brew incorrectly"
[ "$(wc -l < "$brew_log" | tr -d ' ')" -eq 1 ] || \
  fail "system-packages called brew more than once"
[ ! -s "$danger_log" ] || fail "system-packages ran a forbidden command"

: > "$brew_log"
: > "$danger_log"
if env -i HOME="$test_root/home" PATH="$base_path" BREW_SEARCH_PATHS= \
  DOTFILES_BREW_LOG="$brew_log" DOTFILES_DANGER_LOG="$danger_log" \
  make -s -C "$repo" PLATFORM=macos PACKAGE_MANAGER=brew system-packages \
    > "$test_root/system-missing.out" 2>&1; then
  fail "system-packages succeeded without Homebrew"
fi
grep -F 'Homebrew is required' "$test_root/system-missing.out" >/dev/null || \
  fail "system-packages failure was not actionable"
[ ! -s "$brew_log" ] || fail "system-packages ran brew after discovery failed"
[ ! -s "$danger_log" ] || fail "missing system-packages ran a forbidden command"

output=$(env -i HOME="$test_root/home" PATH="$base_path" \
  make -s -C "$repo" PLATFORM=linux brew)
printf '%s\n' "$output" | grep -F 'brew target is macOS only' >/dev/null || \
  fail "Linux brew target did not explain its scope"

echo "check-brew: ok"
