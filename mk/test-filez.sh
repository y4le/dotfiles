#!/bin/bash

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
fail() { echo "check-filez: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
filez=$repo/scripts/.local/bin/filez
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/home" "$test_root/project" "$test_root/empty"
export HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

assert_path_count() {
  local list=$1 expected=$2 wanted=$3 path count=0
  while IFS= read -r -d '' path; do
    [[ $path != "$expected" ]] || count=$((count + 1))
  done < "$list"
  [[ $count = "$wanted" ]] || fail "$expected: wanted $wanted occurrence(s), got $count"
}
expect_status() {
  local wanted=$1 status=0
  shift
  "$@" > "$test_root/status.list" 2> "$test_root/status.err" || status=$?
  [[ $status = "$wanted" ]] || fail "$*: wanted status $wanted, got $status"
}

# These calls use the checkout directly with no installed shell helper.
echo 'check-filez: Git membership and arbitrary filenames'
cd "$test_root/project"
git init -q
mkdir -p sub
printf 'tracked\n' > tracked
printf 'tab\n' > $'tab\tname'
printf 'newline\n' > $'new\nname'
printf 'hidden\n' > .tracked
printf 'tracked ignored\n' > tracked-ignored
printf 'subdir\n' > sub/choice
printf 'deleted\n' > deleted
printf 'ignored\ntracked-ignored\n' > .gitignore
git add tracked $'tab\tname' $'new\nname' .tracked .gitignore sub/choice deleted
git add -f tracked-ignored
ln -s tracked linked
ln -s absent broken
ln -s sub directory-link
git add linked broken directory-link
rm deleted
printf 'ignored\n' > ignored
printf 'new\n' > untracked
printf 'hidden new\n' > .untracked
"$filez" --print0 > "$test_root/list"
for path in tracked $'tab\tname' $'new\nname' .tracked tracked-ignored sub/choice linked untracked .untracked; do
  assert_path_count "$test_root/list" "./$path" 1
done
for path in ignored deleted broken directory-link .git/HEAD; do
  assert_path_count "$test_root/list" "./$path" 0
done
if command -v fzf >/dev/null 2>&1; then
  "$filez" -0 | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' \
    fzf --read0 --print0 --filter 'name' > "$test_root/fzf.list"
  assert_path_count "$test_root/fzf.list" $'./new\nname' 1
  assert_path_count "$test_root/fzf.list" $'./tab\tname' 1
else
  echo 'check-filez: fzf unavailable; real NUL filter check skipped'
fi
"$filez" -h -0 > "$test_root/hidden.list"
cmp -s "$test_root/list" "$test_root/hidden.list" || fail '--hidden changed Git membership'

# Multiple merge stages must become one working-tree candidate.
blob=$(git hash-object -w tracked)
printf '100644 %s 1\tconflicted\n100644 %s 2\tconflicted\n100644 %s 3\tconflicted\n' \
  "$blob" "$blob" "$blob" | git update-index --index-info
printf 'conflict\n' > conflicted
"$filez" -0 > "$test_root/conflict.list"
assert_path_count "$test_root/conflict.list" ./conflicted 1
git update-index --force-remove conflicted

cd sub
"$filez" -0 > "$test_root/sub.list"
printf './choice\0' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/sub.list" || fail 'Git scope expanded beyond the requested subdirectory'
"$filez" > "$test_root/sub.lines"
printf './choice\n' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/sub.lines" || fail 'newline output changed paths'

# Explicit roots remain openable from the caller, including CDPATH and symlinks.
cd "$test_root"
CDPATH="$test_root" "$filez" -0 -r project > "$test_root/root.list"
assert_path_count "$test_root/root.list" "$test_root/project/tracked" 1
ln -s project project-link
"$filez" -0 --root project-link > "$test_root/link.list"
cmp -s "$test_root/root.list" "$test_root/link.list" || fail '--root did not resolve physical paths'
odd_root=$test_root/$'-root space%#\t\n'
mkdir -p "$odd_root"
printf 'odd root\n' > "$odd_root/choice"
"$filez" -0 -r "$odd_root" > "$test_root/odd-root.list"
assert_path_count "$test_root/odd-root.list" "$odd_root/choice" 1
mkdir -- -root
printf 'dash\n' > ./-root/choice
"$filez" -0 -r -root > "$test_root/dash-root.list"
assert_path_count "$test_root/dash-root.list" "$test_root/-root/choice" 1
mkdir -- -
printf 'literal dash\n' > ./-/choice
OLDPWD="$test_root/project" "$filez" -0 -r - > "$test_root/literal-dash.list"
assert_path_count "$test_root/literal-dash.list" "$test_root/-/choice" 1

# Both empty filesystem and Git listings are successful.
cd "$test_root/empty"
"$filez" -0 > "$test_root/empty.list"
[[ ! -s "$test_root/empty.list" ]] || fail 'empty directory listed unrelated paths'
git init -q "$test_root/empty-git"
"$filez" -0 -r "$test_root/empty-git" > "$test_root/empty-git.list"
[[ ! -s "$test_root/empty-git.list" ]] || fail 'empty Git listing used another source'

# Worktrees use their own index and root; .git is a file, not a directory.
git -C "$test_root/project" -c user.name=test -c user.email=test@example.invalid \
  commit -qm fixture -- tracked .gitignore
# Only two paths were committed; leave the other index fixtures alone.
git -C "$test_root/project" worktree add -q --detach "$test_root/worktree" HEAD
"$filez" -0 -r "$test_root/worktree" > "$test_root/worktree.list"
assert_path_count "$test_root/worktree.list" "$test_root/worktree/tracked" 1
assert_path_count "$test_root/worktree.list" "$test_root/worktree/.git" 0
mkdir -p "$test_root/project/submodule"
printf 'nested\n' > "$test_root/project/submodule/choice"
head=$(git -C "$test_root/project" rev-parse HEAD)
git -C "$test_root/project" update-index --add --cacheinfo "160000,$head,submodule"
"$filez" -0 -r "$test_root/project" > "$test_root/submodule.list"
assert_path_count "$test_root/submodule.list" "$test_root/project/submodule" 0
assert_path_count "$test_root/submodule.list" "$test_root/project/submodule/choice" 0

# Git metadata roots get a useful error instead of silent success or a scan.
expect_status 1 "$filez" -0 -r "$test_root/project/.git"
grep -q 'Git metadata' "$test_root/status.err" || fail 'metadata error lacked a diagnostic'
[[ ! -s "$test_root/status.list" ]] || fail 'Git metadata leaked into the listing'
git init -q --bare "$test_root/bare"
expect_status 1 "$filez" -0 -r "$test_root/bare"
grep -q 'Git metadata' "$test_root/status.err" || fail 'bare repository error lacked a diagnostic'
for root in "$test_root/project/.git/hooks" "$test_root/bare/objects" \
  "$test_root/project/.git/worktrees/worktree"; do
  expect_status 1 "$filez" -0 -r "$root"
  grep -q 'Git metadata' "$test_root/status.err" || fail "metadata subtree lacked a diagnostic: $root"
done

# A real damaged index is still a Git source error, never a filesystem scan.
git init -q "$test_root/corrupt-git"
printf 'tracked\n' > "$test_root/corrupt-git/choice"
git -C "$test_root/corrupt-git" add choice
printf 'corrupt index\n' > "$test_root/corrupt-git/.git/index"
expect_status 128 "$filez" -0 -r "$test_root/corrupt-git"
[[ ! -s "$test_root/status.list" ]] || fail 'corrupt index triggered a filesystem fallback'
grep -q 'index' "$test_root/status.err" || fail 'corrupt index diagnostic was lost'

# Filesystem traversal follows rg ignore rules, without ambient rg CLI config.
echo 'check-filez: filesystem policy and strict CLI'
mkdir -p "$test_root/plain/.git" "$test_root/plain/.hidden-dir"
cd "$test_root/plain"
printf 'visible\n' > plain
printf 'hidden\n' > .hidden
printf 'nested hidden\n' > .hidden-dir/choice
printf 'ignored\n' > ignored
printf 'ignored\n' > .ignore
printf 'metadata\n' > .git/private
printf 'special\n' > $'line\nbreak'
printf 'special\n' > $'tab\tname'
printf 'special\n' > '-leading-dash'
printf '%s\n' '--glob=!plain' > "$test_root/rg-config"
RIPGREP_CONFIG_PATH="$test_root/rg-config" "$filez" -0 > "$test_root/plain.list"
for path in plain $'line\nbreak' $'tab\tname' '-leading-dash'; do
  assert_path_count "$test_root/plain.list" "./$path" 1
done
for path in .hidden .hidden-dir/choice ignored .git/private; do
  assert_path_count "$test_root/plain.list" "./$path" 0
done
"$filez" --hidden --print0 --debug > "$test_root/plain-hidden.list" 2> "$test_root/debug.err"
for path in .hidden .hidden-dir/choice; do
  assert_path_count "$test_root/plain-hidden.list" "./$path" 1
done
assert_path_count "$test_root/plain-hidden.list" ./.git/private 0
grep -q 'filez source: filesystem_files (root: .)' "$test_root/debug.err" || fail 'debug output omitted the source'
"$filez" --help > "$test_root/help"
grep -q 'Usage: filez' "$test_root/help" || fail '--help did not print usage'
expect_status 2 "$filez" --unknown
expect_status 2 "$filez" positional
expect_status 2 "$filez" -- positional
expect_status 2 "$filez" --root
expect_status 2 "$filez" --root ''
expect_status 1 "$filez" --root missing
expect_status 1 "$filez" --root plain
"$filez" -0 -- > "$test_root/end-options.list"
for path in plain $'line\nbreak' $'tab\tname' '-leading-dash'; do
  assert_path_count "$test_root/end-options.list" "./$path" 1
done
for path in .hidden .hidden-dir/choice ignored .git/private; do
  assert_path_count "$test_root/end-options.list" "./$path" 0
done

# Inject producer failures: keep output/status/diagnostics, never retry a source.
echo 'check-filez: partial errors and missing dependencies'
partial_bin=$test_root/partial-bin
mkdir -p "$partial_bin"
ln -s "$(command -v tr)" "$partial_bin/tr"
cat > "$partial_bin/rg" <<'STUB'
#!/bin/sh
printf './partial\000'
printf 'rg fixture error\n' >&2
exit 2
STUB
for backend in fd find; do
  cat > "$partial_bin/$backend" <<'STUB'
#!/bin/sh
printf fallback >> "$DOTFILES_FALLBACK_LOG"
STUB
done
chmod +x "$partial_bin/rg" "$partial_bin/fd" "$partial_bin/find"
export DOTFILES_FALLBACK_LOG="$test_root/fallback.log"
: > "$DOTFILES_FALLBACK_LOG"
expect_status 2 env PATH="$partial_bin" "$filez" -0
printf './partial\0' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/status.list" || fail 'partial rg output was changed or duplicated'
grep -q 'rg fixture error' "$test_root/status.err" || fail 'rg diagnostic was lost'
expect_status 2 env PATH="$partial_bin" "$filez"
printf './partial\n' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/status.list" || fail 'newline conversion changed partial output'
rm "$partial_bin/rg"
expect_status 127 env PATH="$partial_bin" "$filez" -0
grep -q 'ripgrep is required' "$test_root/status.err" || fail 'missing rg lacked an actionable diagnostic'
[[ ! -s "$DOTFILES_FALLBACK_LOG" ]] || fail 'rg failure or absence invoked fd/find'

# Git may emit paths before failing; pipeline status must survive filtering.
printf 'partial\n' > partial
cat > "$partial_bin/git" <<'STUB'
#!/bin/sh
shift 2 # -C ROOT
case $1 in
  rev-parse) printf 'true\n' ;;
  ls-files)
    printf 'partial\000'
    printf 'Git fixture error\n' >&2
    exit 7 ;;
esac
STUB
chmod +x "$partial_bin/git"
expect_status 7 env PATH="$partial_bin" "$filez" -0
printf './partial\0' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/status.list" || fail 'partial Git result was lost'
grep -q 'Git fixture error' "$test_root/status.err" || fail 'Git diagnostic was lost'
expect_status 7 env PATH="$partial_bin" "$filez"
printf './partial\n' > "$test_root/expected"
cmp -s "$test_root/expected" "$test_root/status.list" || fail 'newline conversion swallowed the Git result'

echo 'check-filez: ok'
