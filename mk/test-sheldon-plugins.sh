#!/bin/sh

set -eu

fail() {
  echo "check-sheldon: $*" >&2
  exit 1
}

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P) || exit 1
cd "$repo"

test_root=$(mktemp -d) || exit 1
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

verify_script=$repo/mk/verify-sheldon-plugins.sh
real_config=$repo/zsh/.config/sheldon/plugins.toml
real_mise=$repo/mise/.config/mise/config.toml
real_git=$(command -v git) || fail "git not found"

echo "check-sheldon: config lint"
sh "$verify_script" lint "$real_config" "$real_mise"

expect_lint_failure() {
  label=$1
  config=$2
  mise_config=${3:-$real_mise}
  if sh "$verify_script" lint "$config" "$mise_config" >/dev/null 2>&1; then
    fail "accepted $label"
  fi
}

mutated=$test_root/plugins.toml
awk 'BEGIN { skip = 0 } !skip && /^rev =/ { skip = 1; next } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "a missing rev" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^rev =/ { $0 = "rev = \"1234567\""; changed = 1 } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "a short rev" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^rev =/ { $0 = "rev = \"v0.70.0\""; changed = 1 } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "a tag used as rev" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^rev =/ { sub(/"[0-9a-f]/, "\"A"); changed = 1 } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "an uppercase rev" "$mutated"

awk 'BEGIN { added = 0 } { print } !added && /^github =/ { print "tag = \"v1\""; added = 1 }' \
  "$real_config" > "$mutated"
expect_lint_failure "a tag key" "$mutated"

awk 'BEGIN { added = 0 } { print } !added && /^github =/ { print "branch = \"main\""; added = 1 }' \
  "$real_config" > "$mutated"
expect_lint_failure "a branch key" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^github =/ { sub(/^github/, "remote"); changed = 1 } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "a remote plugin" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^github =/ { sub(/^github/, "git"); changed = 1 } { print }' \
  "$real_config" > "$mutated"
expect_lint_failure "a git plugin" "$mutated"

awk 'BEGIN { added = 0 } { print } !added && /^github =/ {
  print "local = \"~/.config/zsh/themes\""; added = 1
}' "$real_config" > "$mutated"
expect_lint_failure "github and local together" "$mutated"

awk 'BEGIN { added = 0 } { print } !added && /^local =/ {
  print "rev = \"0123456789012345678901234567890123456789\""; added = 1
}' "$real_config" > "$mutated"
expect_lint_failure "a rev on a local plugin" "$mutated"

sed 's/use = \["minimal\.zsh-theme"\]/use = ["*.zsh"]/' \
  "$real_config" > "$mutated"
expect_lint_failure "a glob in local use" "$mutated"

sed 's/use = \["minimal\.zsh-theme"\]/use = ["missing.zsh"]/' \
  "$real_config" > "$mutated"
expect_lint_failure "an untracked local file" "$mutated"

sed 's#use = \["shell/\*\.zsh"\]#use = ["../escape.zsh"]#' \
  "$real_config" > "$mutated"
expect_lint_failure "a parent path in github use" "$mutated"

sed 's#use = \["shell/\*\.zsh"\]#use = ["/etc/zshrc"]#' \
  "$real_config" > "$mutated"
expect_lint_failure "an absolute path in github use" "$mutated"

cp "$real_config" "$mutated"
printf '%s\n' \
  '[plugins.duplicate-repo]' \
  'github = "romkatv/zsh-defer"' \
  'rev = "0123456789012345678901234567890123456789"' >> "$mutated"
expect_lint_failure "conflicting revs for one repo" "$mutated"

sed 's/" # v0\.70\.0/"/' "$real_config" > "$mutated"
expect_lint_failure "a missing fzf version note" "$mutated"

sed 's/# v0\.70\.0/# v0.71.0/' "$real_config" > "$mutated"
expect_lint_failure "a mismatched fzf version note" "$mutated"

mise_without_fzf=$test_root/mise-without-fzf.toml
awk '!/aqua:junegunn\/fzf/' "$real_mise" > "$mise_without_fzf"
expect_lint_failure "a missing mise fzf pin" "$real_config" "$mise_without_fzf"

awk 'BEGIN { changed = 0 } !changed && /^apply =/ {
  print "apply = ["; print "  \"source\""; print "]"; changed = 1; next
} { print }' "$real_config" > "$mutated"
expect_lint_failure "a multiline array" "$mutated"

awk 'BEGIN { changed = 0 } !changed && /^github =/ {
  gsub(/"/, "\047"); changed = 1
} { print }' "$real_config" > "$mutated"
expect_lint_failure "a single-quoted string" "$mutated"

echo "check-sheldon: checkout verification"
fixture_home=$test_root/home
config=$fixture_home/.config/sheldon/plugins.toml
data=$fixture_home/.local/share/sheldon
cache=$fixture_home/.cache/dotfiles/sheldon.zsh
bin=$test_root/bin
mkdir -p "$(dirname "$config")" "$(dirname "$cache")" "$bin"

git_env() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.com \
    GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.com \
    "$real_git" "$@"
}

make_checkout() {
  name=$1
  directory=$data/repos/github.com/fixture/$name
  mkdir -p "$directory"
  git_env -C "$directory" init -q
  printf '%s first\n' "$name" > "$directory/$name.plugin.zsh"
  mkdir -p "$directory/shell"
  printf '%s shell first\n' "$name" > "$directory/shell/a.zsh"
  git_env -C "$directory" add .
  git_env -C "$directory" commit -qm first
  first=$(git_env -C "$directory" rev-parse HEAD)
  printf '%s second\n' "$name" >> "$directory/$name.plugin.zsh"
  git_env -C "$directory" commit -qam second
  second=$(git_env -C "$directory" rev-parse HEAD)
  git_env -C "$directory" checkout -q --detach "$first"
  printf '%s %s\n' "$first" "$second"
}

alpha_revs=$(make_checkout alpha)
alpha_first=${alpha_revs%% *}
alpha_second=${alpha_revs#* }
beta_revs=$(make_checkout beta)
beta_first=${beta_revs%% *}

write_fixture_config() {
  cat > "$config" <<EOF
shell = "zsh"

[templates]
defer = "zsh-defer source {{ file }}"

[plugins.alpha]
github = "fixture/alpha"
rev = "$alpha_first"

[plugins.beta]
github = "fixture/beta"
rev = "$beta_first"
use = ["shell/a.zsh"]
apply = ["defer"]

[plugins.local-theme]
local = "~/.config/zsh/themes"
use = ["theme.zsh"]
EOF
}
write_fixture_config
mkdir -p "$fixture_home/.config/zsh/themes"
printf 'theme\n' > "$fixture_home/.config/zsh/themes/theme.zsh"

stub_mode=$test_root/stub-mode
printf success > "$stub_mode"
stub_sheldon=$bin/sheldon
cat > "$stub_sheldon" <<'EOF'
#!/bin/sh
[ "$SHELDON_CONFIG_FILE" = "$DOTFILES_EXPECT_CONFIG" ] || exit 64
[ "$SHELDON_DATA_DIR" = "$DOTFILES_EXPECT_DATA" ] || exit 65
mode=$(cat "$DOTFILES_STUB_MODE")
case $1 in
  lock) [ "$mode" != lock-fail ] || exit 2 ;;
  source)
    if [ "$mode" = local-only ]; then
      printf 'source "%s/.config/zsh/themes/theme.zsh"\n' "$HOME"
      exit 0
    fi
    [ "$mode" = omit-alpha ] || \
      printf 'source "%s/repos/github.com/fixture/alpha/alpha.plugin.zsh"\n' "$SHELDON_DATA_DIR"
    printf 'zsh-defer source "%s/repos/github.com/fixture/beta/shell/a.zsh"\n' "$SHELDON_DATA_DIR"
    printf 'source "%s/.config/zsh/themes/theme.zsh"\n' "$HOME"
    [ "$mode" != extra ] || \
      printf 'source "%s/repos/github.com/other/repo/evil.zsh"\n' "$SHELDON_DATA_DIR"
    ;;
  *) exit 66 ;;
esac
EOF
chmod +x "$stub_sheldon"

network_log=$test_root/network.log
git_log=$test_root/git.log
for command_name in curl wget; do
  # These single-quoted lines are the body of the generated command stubs.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s %s\n" "$0" "$*" >> "$DOTFILES_NETWORK_LOG"' \
    'exit 97' > "$bin/$command_name"
  chmod +x "$bin/$command_name"
done
# These single-quoted lines are the body of the generated git stub.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s\n" "$*" >> "$DOTFILES_GIT_LOG"' \
  'case " $* " in' \
  '  *" clone "* | *" fetch "* | *" pull "* | *" ls-remote "* | *" remote "* | *" submodule "*) exit 98 ;;' \
  'esac' \
  'exec "$DOTFILES_REAL_GIT" "$@"' > "$bin/git"
chmod +x "$bin/git"

run_plugins() {
  env -i HOME="$fixture_home" PATH="$bin:/usr/local/bin:/usr/bin:/bin" \
    HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=http://127.0.0.1:9 GIT_CONFIG_NOSYSTEM=1 \
    DOTFILES_EXPECT_CONFIG="$config" DOTFILES_EXPECT_DATA="$data" \
    DOTFILES_STUB_MODE="$stub_mode" DOTFILES_NETWORK_LOG="$network_log" \
    DOTFILES_GIT_LOG="$git_log" DOTFILES_REAL_GIT="$real_git" \
    make -s -C "$repo" SHELDON_BIN="$stub_sheldon" \
      SHELDON_CONFIG_FILE="$config" SHELDON_DATA_DIR="$data" sheldon-plugins
}

reset_checkouts() {
  git_env -C "$data/repos/github.com/fixture/alpha" update-index \
    --no-assume-unchanged alpha.plugin.zsh shell/a.zsh
  git_env -C "$data/repos/github.com/fixture/alpha" update-index \
    --no-skip-worktree alpha.plugin.zsh shell/a.zsh
  git_env -C "$data/repos/github.com/fixture/alpha" checkout -q --detach "$alpha_first"
  git_env -C "$data/repos/github.com/fixture/alpha" reset -q --hard
  git_env -C "$data/repos/github.com/fixture/alpha" clean -q -fdx
  git_env -C "$data/repos/github.com/fixture/beta" update-index \
    --no-assume-unchanged beta.plugin.zsh shell/a.zsh
  git_env -C "$data/repos/github.com/fixture/beta" update-index \
    --no-skip-worktree beta.plugin.zsh shell/a.zsh
  git_env -C "$data/repos/github.com/fixture/beta" checkout -q --detach "$beta_first"
  git_env -C "$data/repos/github.com/fixture/beta" reset -q --hard
  git_env -C "$data/repos/github.com/fixture/beta" clean -q -fdx
  write_fixture_config
  printf success > "$stub_mode"
}

: > "$network_log"
: > "$git_log"
run_plugins >/dev/null
grep -F 'fixture/alpha/alpha.plugin.zsh' "$cache" >/dev/null || \
  fail "verified cache omitted alpha"
[ ! -s "$network_log" ] || fail "successful verification invoked curl or wget"
if grep -Eq '(^| )(clone|fetch|pull|ls-remote|remote|submodule)( |$)' "$git_log"; then
  fail "successful verification invoked a network Git operation"
fi

expect_verify_failure() {
  label=$1
  expected_message=$2
  printf 'known last good\n' > "$cache"
  before=$(cksum < "$cache")
  : > "$network_log"
  : > "$git_log"
  if run_plugins > "$test_root/failure.out" 2>&1; then
    fail "$label succeeded"
  fi
  [ "$(cksum < "$cache")" = "$before" ] || fail "$label replaced the last-good cache"
  grep -F "$expected_message" "$test_root/failure.out" >/dev/null || \
    fail "$label did not report $expected_message"
  for leftover in "$(dirname "$cache")"/sheldon.zsh.tmp.*; do
    if [ -e "$leftover" ] || [ -L "$leftover" ]; then
      fail "$label leaked a temporary cache"
    fi
  done
  [ ! -s "$network_log" ] || fail "$label invoked curl or wget"
  if grep -Eq '(^| )(clone|fetch|pull|ls-remote|remote|submodule)( |$)' "$git_log"; then
    fail "$label invoked a network Git operation"
  fi
}

git_env -C "$data/repos/github.com/fixture/alpha" checkout -q --detach "$alpha_second"
expect_verify_failure "off-pin checkout" "plugin alpha"
reset_checkouts

printf 'dirty\n' >> "$data/repos/github.com/fixture/alpha/alpha.plugin.zsh"
expect_verify_failure "tracked checkout change" "plugin alpha"
reset_checkouts

printf 'untracked\n' > "$data/repos/github.com/fixture/beta/shell/evil.zsh"
expect_verify_failure "untracked checkout file" "plugin beta"
reset_checkouts

printf '*.zwc\n' > "$data/repos/github.com/fixture/alpha/.git/info/exclude"
printf 'ignored\n' > "$data/repos/github.com/fixture/alpha/alpha.plugin.zsh.zwc"
expect_verify_failure "ignored checkout file" "plugin alpha"
reset_checkouts

git_env -C "$data/repos/github.com/fixture/alpha" update-index \
  --assume-unchanged alpha.plugin.zsh
printf 'hidden\n' >> "$data/repos/github.com/fixture/alpha/alpha.plugin.zsh"
expect_verify_failure "assume-unchanged checkout file" "plugin alpha"
reset_checkouts

git_env -C "$data/repos/github.com/fixture/alpha" update-index \
  --skip-worktree alpha.plugin.zsh
printf 'hidden\n' >> "$data/repos/github.com/fixture/alpha/alpha.plugin.zsh"
expect_verify_failure "skip-worktree checkout file" "plugin alpha"
reset_checkouts

git_env -C "$data/repos/github.com/fixture/alpha" replace "$alpha_first" "$alpha_second"
git_env -C "$data/repos/github.com/fixture/alpha" read-tree -u --reset HEAD
expect_verify_failure "replace-object checkout" "plugin alpha"
git_env -C "$data/repos/github.com/fixture/alpha" replace -d "$alpha_first" >/dev/null
reset_checkouts

mv "$data/repos/github.com/fixture/beta" "$test_root/beta-away"
expect_verify_failure "missing checkout" "plugin beta"
mv "$test_root/beta-away" "$data/repos/github.com/fixture/beta"
reset_checkouts

mv "$data/repos/github.com/fixture/beta/.git" "$test_root/beta-gitdir"
ln -s "$test_root/beta-gitdir" "$data/repos/github.com/fixture/beta/.git"
expect_verify_failure "linked Git metadata" "plugin beta"
rm "$data/repos/github.com/fixture/beta/.git"
mv "$test_root/beta-gitdir" "$data/repos/github.com/fixture/beta/.git"
reset_checkouts

mv "$data/repos/github.com/fixture/beta" "$test_root/beta-away"
ln -s "$test_root/beta-away" "$data/repos/github.com/fixture/beta"
expect_verify_failure "linked checkout" "plugin beta"
rm "$data/repos/github.com/fixture/beta"
mv "$test_root/beta-away" "$data/repos/github.com/fixture/beta"
reset_checkouts

awk 'BEGIN { skip = 0 } !skip && /rev =/ { skip = 1; next } { print }' "$config" > "$mutated"
cp "$mutated" "$config"
expect_verify_failure "runtime config without rev" "plugin alpha"
reset_checkouts

printf omit-alpha > "$stub_mode"
expect_verify_failure "cache missing a pinned checkout" "plugin alpha"
reset_checkouts

printf extra > "$stub_mode"
expect_verify_failure "cache contains an unpinned checkout" "unpinned checkout"
reset_checkouts

printf lock-fail > "$stub_mode"
expect_verify_failure "Sheldon lock failure" "Error"
reset_checkouts

local_config=$test_root/local-only.toml
cat > "$local_config" <<'EOF'
shell = "zsh"
[plugins.local-theme]
local = "~/.config/zsh/themes"
use = ["theme.zsh"]
EOF
config=$local_config
data=$test_root/missing-data
printf local-only > "$stub_mode"
run_plugins >/dev/null || fail "local-only plugin config failed verification"

echo "check-sheldon: real Sheldon integration"
real_sheldon=${DOTFILES_TEST_SHELDON:-$HOME/.local/bin/sheldon}
if DOTFILES_PINS_FILE="$repo/setup/pins/downloads.txt" \
  sh "$repo/mk/pinned.sh" status sheldon "$real_sheldon" >/dev/null 2>&1; then
  real_home=$test_root/real-home
  real_data=$real_home/.local/share/sheldon
  real_config=$real_home/.config/sheldon/plugins.toml
  real_cache=$real_home/.cache/dotfiles/sheldon.zsh
  work=$test_root/origin-work
  real_checkout=$real_data/repos/github.com/fixture/alpha
  mkdir -p "$work" "$(dirname "$real_checkout")" "$(dirname "$real_config")"
  git_env -C "$work" init -q
  printf 'alpha real\n' > "$work/alpha.plugin.zsh"
  git_env -C "$work" add .
  git_env -C "$work" commit -qm first
  real_rev=$(git_env -C "$work" rev-parse HEAD)
  git_env clone -q "$work" "$real_checkout"
  cat > "$real_config" <<EOF
shell = "zsh"
[plugins.alpha]
github = "fixture/alpha"
rev = "$real_rev"
EOF
  cat > "$real_data/plugins.lock" <<EOF
version = "0.8.5"
home = "$real_home"
config_dir = "${real_config%/*}"
data_dir = "$real_data"
config_file = "$real_config"

[[plugins]]
name = "alpha"
source_dir = "$real_checkout"
files = ["$real_checkout/alpha.plugin.zsh"]
apply = ["source"]

[plugins.hooks]

[templates]
source = """
{{ hooks?.pre | nl }}{% for file in files %}source "{{ file }}"
{% endfor %}{{ hooks?.post | nl }}"""
EOF
  config=$real_config
  data=$real_data
  cache=$real_cache
  stub_sheldon=$real_sheldon
  mkdir -p "$(dirname "$cache")"
  run_plugins >/dev/null || fail "real Sheldon could not restore the pinned fixture"
  printf 'dirty\n' >> "$data/repos/github.com/fixture/alpha/alpha.plugin.zsh"
  printf 'real last good\n' > "$cache"
  real_before=$(cksum < "$cache")
  if run_plugins > "$test_root/real-dirty.out" 2>&1; then
    fail "real Sheldon accepted a dirty checkout"
  fi
  [ "$(cksum < "$cache")" = "$real_before" ] || \
    fail "real Sheldon dirty failure replaced the cache"
else
  echo "check-sheldon: pinned Sheldon fixture not found; skipping real integration"
fi

echo "check-sheldon: ok"
