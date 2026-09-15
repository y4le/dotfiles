#!/bin/sh

set -u

fail() {
  echo "check-link: $*" >&2
  exit 1
}

test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

repo=$test_root/home/dev/dotfiles
mkdir -p "$repo" || exit 1

file_list=$test_root/files
git ls-files > "$file_list" || exit 1
repo_archive=$test_root/repo.tar
tar -cf "$repo_archive" -T "$file_list" || exit 1
tar -xf "$repo_archive" -C "$repo" || exit 1
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" init -q || exit 1
# Preserve paths that are tracked by the source repository despite matching a
# broad runtime ignore rule. A real clone retains that distinction too.
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" add -Af . || exit 1
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" \
  -c commit.gpgsign=false -c user.name=test -c user.email=test@example.invalid \
  commit -qm candidate || exit 1

run_make() {
  test_home=$1
  shift
  env -i \
    HOME="$test_home" \
    PATH="$PATH" \
    SHELL=/bin/sh \
    LC_ALL=C \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 \
    make -C "$repo" "$@"
}

snapshot_home() {
  test_home=$1
  (
    cd "$test_home" || exit 1
    find . -path ./dev -prune -o -print | LC_ALL=C sort | while IFS= read -r path; do
      if [ -L "$path" ]; then
        printf 'L %s -> %s\n' "$path" "$(readlink "$path")"
      elif [ -d "$path" ]; then
        printf 'D %s\n' "$path"
      elif [ -f "$path" ]; then
        printf 'F %s ' "$path"
        cksum < "$path"
      fi
    done
  )
}

assert_no_directory_links() {
  test_home=$1
  find "$test_home" -type l -print | while IFS= read -r path; do
    if [ -d "$path" ]; then
      echo "check-link: directory symlink found: $path" >&2
      exit 1
    fi
  done
}

echo "check-link: fresh and idempotent link"
fresh_home=$test_root/fresh-home
mkdir -p "$fresh_home"
fresh_log=$test_root/fresh-link.log
if ! run_make "$fresh_home" link > "$fresh_log" 2>&1; then
  cat "$fresh_log" >&2
  fail "fresh link failed"
fi
[ -L "$fresh_home/.zshrc" ] || fail "fresh link did not create .zshrc"
[ "$(readlink "$fresh_home/.zshrc")" = "../home/dev/dotfiles/zsh/.zshrc" ] || \
  fail "fresh .zshrc points to the wrong source"
[ -d "$fresh_home/.config/nvim" ] && [ ! -L "$fresh_home/.config/nvim" ] || \
  fail "fresh link folded .config/nvim"
[ -L "$fresh_home/.config/nvim/init.lua" ] || \
  fail "fresh link did not create nvim/init.lua"
assert_no_directory_links "$fresh_home" || fail "fresh link folded directories"
snapshot_home "$fresh_home" > "$test_root/fresh-before"
run_make "$fresh_home" link >/dev/null 2>&1 || fail "second link failed"
snapshot_home "$fresh_home" > "$test_root/fresh-after"
cmp -s "$test_root/fresh-before" "$test_root/fresh-after" || \
  fail "second link changed HOME"

echo "check-link: conflict is non-mutating"
conflict_home=$test_root/conflict-home
mkdir -p "$conflict_home/.config/gh"
printf 'existing zsh config\n' > "$conflict_home/.zshenv"
printf 'oauth_token: secret\n' > "$conflict_home/.config/gh/hosts.yml"
snapshot_home "$conflict_home" > "$test_root/conflict-before"
if run_make "$conflict_home" link-plan > "$test_root/conflict-plan.log" 2>&1; then
  fail "link-plan accepted a conflicting HOME"
fi
if run_make "$conflict_home" link > "$test_root/conflict-link.log" 2>&1; then
  fail "link accepted a conflicting HOME"
fi
grep -q '.zshenv' "$test_root/conflict-link.log" || \
  fail "conflict failure did not name .zshenv"
snapshot_home "$conflict_home" > "$test_root/conflict-after"
cmp -s "$test_root/conflict-before" "$test_root/conflict-after" || \
  fail "conflicting link changed HOME"

echo "check-link: package artifact guard"
artifact_home=$test_root/artifact-home
mkdir -p "$artifact_home" "$repo/vim/.vim/autoload"
printf 'generated artifact\n' > "$repo/vim/.vim/autoload/plug.vim"
if run_make "$artifact_home" link > "$test_root/artifact.log" 2>&1; then
  fail "link accepted an untracked package artifact"
fi
grep -q 'vim/.vim/autoload/plug.vim' "$test_root/artifact.log" || \
  fail "artifact failure did not name the file"
rm -f "$repo/vim/.vim/autoload/plug.vim"

echo "check-link: legacy folded layout migration"
legacy_home=$test_root/legacy-home
mkdir -p "$legacy_home"
legacy_packages=$(run_make "$legacy_home" -s --no-print-directory _print-packages) || \
  fail "could not determine legacy package set"
for package in $legacy_packages; do
  "$(command -v stow)" -d "$repo" -t "$legacy_home" "$package" \
    >/dev/null 2>&1 || fail "legacy layout setup failed for $package"
done
[ -L "$legacy_home/.vim" ] || fail "legacy setup did not fold .vim"
legacy_log=$test_root/legacy-link.log
if ! run_make "$legacy_home" link > "$legacy_log" 2>&1; then
  cat "$legacy_log" >&2
  fail "legacy migration failed"
fi
[ -d "$legacy_home/.vim" ] && [ ! -L "$legacy_home/.vim" ] || \
  fail "legacy .vim directory remained folded"
assert_no_directory_links "$legacy_home" || fail "legacy migration left directory links"

echo "check-link: clean removes managed links"
clean_home=$test_root/clean-home
mkdir -p "$clean_home"
run_make "$clean_home" link >/dev/null 2>&1 || fail "clean setup link failed"
printf 'keep me\n' > "$clean_home/.config/user-owned"
run_make "$clean_home" clean >/dev/null 2>&1 || fail "clean failed"
if find "$clean_home" -type l -print | grep -q .; then
  fail "clean left managed links"
fi
[ -f "$clean_home/.config/user-owned" ] || fail "clean removed a user file"

echo "check-link: ok"
