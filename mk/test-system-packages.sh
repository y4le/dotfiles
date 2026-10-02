#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

fail() {
  echo "check-system-packages: $*" >&2
  exit 1
}

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/home"
printf 'curl\ngit\n' > "$test_root/apt-packages.txt"

cat > "$test_root/bin/sudo" <<'EOF'
#!/bin/sh
if [ "$1" = pacman ]; then
  printf '%s\n' "$*" >> "$DOTFILES_PACMAN_LOG"
  exit "${DOTFILES_PACMAN_EXIT:-0}"
fi
printf '%s\n' "$*" >> "$DOTFILES_APT_LOG"
if [ "$*" = 'apt-get update' ]; then
  exit "${DOTFILES_APT_UPDATE_EXIT:-0}"
fi
exit 0
EOF
chmod +x "$test_root/bin/sudo"

run_packages() {
  env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
    DOTFILES_APT_LOG="$test_root/apt.log" \
    DOTFILES_APT_UPDATE_EXIT="$1" \
    make -s -C "$repo" PLATFORM=linux PACKAGE_MANAGER=apt \
      APT_PACKAGES_FILE="$test_root/apt-packages.txt" system-packages
}

echo "check-system-packages: failed apt update stops installation"
if run_packages 42 > "$test_root/failed.out" 2>&1; then
  fail "system-packages succeeded after apt-get update failed"
fi
[ "$(cat "$test_root/apt.log")" = 'apt-get update' ] || \
  fail "system-packages continued after apt-get update failed"

echo "check-system-packages: successful apt update installs packages"
: > "$test_root/apt.log"
run_packages 0 > "$test_root/success.out" 2>&1 || \
  fail "system-packages failed after apt-get update succeeded"
[ "$(sed -n '1p' "$test_root/apt.log")" = 'apt-get update' ] || \
  fail "system-packages did not update before installing"
grep -Fx 'apt-get install -y curl git' "$test_root/apt.log" >/dev/null || \
  fail "system-packages did not install packages"
[ "$(wc -l < "$test_root/apt.log" | tr -d ' ')" -eq 2 ] || \
  fail "system-packages ran unexpected package commands"

run_pacman() {
  env -i HOME="$test_root/home" PATH="$test_root/bin:/usr/bin:/bin" \
    DOTFILES_PACMAN_LOG="$test_root/pacman.log" DOTFILES_PACMAN_EXIT="$1" \
    make -s -C "$repo" PLATFORM=linux PACKAGE_MANAGER=pacman \
      PACMAN_PACKAGES_FILE="$test_root/apt-packages.txt" system-packages
}
echo "check-system-packages: pacman refreshes and upgrades with confirmation"
run_pacman 0 > "$test_root/pacman-success.out" 2>&1 || fail "pacman installation failed"
[ "$(cat "$test_root/pacman.log")" = 'pacman -Syu --needed curl git' ] || \
  fail "pacman skipped refresh/upgrade or suppressed confirmation"
: > "$test_root/pacman.log"
if run_pacman 42 > "$test_root/pacman-failure.out" 2>&1; then
  fail "pacman failure was ignored"
fi
[ "$(cat "$test_root/pacman.log")" = 'pacman -Syu --needed curl git' ] || fail "pacman failure retried installation"

echo "check-system-packages: ok"
