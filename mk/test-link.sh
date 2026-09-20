#!/bin/sh

set -u

fail() {
  echo "check-link: $*" >&2
  exit 1
}

test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM

git_isolated() {
  env -i \
    HOME="$test_root" \
    PATH="$PATH" \
    LC_ALL=C \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 \
    git "$@"
}

repo=$test_root/home/dev/dotfiles
mkdir -p "$repo" || exit 1

file_list=$test_root/files
source_repo=$(pwd -P) || exit 1
git_isolated -C "$source_repo" ls-files > "$file_list" || exit 1
repo_archive=$test_root/repo.tar
tar -cf "$repo_archive" -T "$file_list" || exit 1
tar -xf "$repo_archive" -C "$repo" || exit 1
git_isolated -C "$repo" init -q || exit 1
# Preserve paths that are tracked by the source repository despite matching a
# broad runtime ignore rule. A real clone retains that distinction too.
git_isolated -C "$repo" add -Af . || exit 1
git_isolated -C "$repo" \
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
    find . -print | LC_ALL=C sort | while IFS= read -r path; do
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
[ -L "$fresh_home/.config/tmux/tmux.conf" ] || \
  fail "fresh link did not create the tmux config"
[ -L "$fresh_home/.config/shell/functions/cpst" ] || \
  fail "fresh link did not create shell helpers under XDG config"
[ ! -e "$fresh_home/.funcs" ] || \
  fail "fresh link created the legacy shell helper directory"
[ -L "$fresh_home/.config/ideavim/ideavimrc" ] || \
  fail "fresh link did not create IdeaVim config under XDG config"
[ ! -e "$fresh_home/.ideavimrc" ] || \
  fail "fresh link created the legacy IdeaVim config path"
[ ! -e "$fresh_home/.tmux.conf" ] || \
  fail "fresh link created the legacy tmux config path"
[ -L "$fresh_home/.config/git/config" ] || \
  fail "fresh link did not create the portable Git config"
[ -f "$fresh_home/.gitconfig" ] && [ ! -L "$fresh_home/.gitconfig" ] || \
  fail "fresh link did not create a local Git config"
[ ! -e "$fresh_home/.xsessionrc" ] || \
  fail "default link enabled Linux desktop config"
[ ! -e "$fresh_home/.config/karabiner/karabiner.json" ] || \
  fail "default link enabled macOS desktop config"
portable_git_before=$(cksum < "$repo/git/.config/git/config")
env -i HOME="$fresh_home" PATH="$PATH" LC_ALL=C GIT_CONFIG_NOSYSTEM=1 \
  git config --global user.name Test || \
  fail "git config --global could not write local identity"
grep -q 'name = Test' "$fresh_home/.gitconfig" || \
  fail "git config --global did not write the local Git config"
[ "$(cksum < "$repo/git/.config/git/config")" = "$portable_git_before" ] || \
  fail "git config --global changed the portable Git config"
assert_no_directory_links "$fresh_home" || fail "fresh link folded directories"
snapshot_home "$fresh_home" > "$test_root/fresh-before"
run_make "$fresh_home" link >/dev/null 2>&1 || fail "second link failed"
snapshot_home "$fresh_home" > "$test_root/fresh-after"
cmp -s "$test_root/fresh-before" "$test_root/fresh-after" || \
  fail "second link changed HOME"

echo "check-link: desktop packages are opt-in"
linux_core_home=$test_root/linux-core-home
mkdir -p "$linux_core_home"
run_make "$linux_core_home" PLATFORM=linux link \
  >/dev/null 2>&1 || fail "Linux core link failed"
[ ! -e "$linux_core_home/.xsessionrc" ] || \
  fail "Linux core link included desktop config"

macos_core_home=$test_root/macos-core-home
mkdir -p "$macos_core_home"
run_make "$macos_core_home" PLATFORM=macos link \
  >/dev/null 2>&1 || fail "macOS core link failed"
[ -L "$macos_core_home/.config/zsh/sources/osx.zsh" ] || \
  fail "macOS core link omitted shell config"
[ ! -e "$macos_core_home/.config/karabiner/karabiner.json" ] || \
  fail "macOS core link included desktop config"

linux_desktop_home=$test_root/linux-desktop-home
mkdir -p "$linux_desktop_home"
run_make "$linux_desktop_home" PLATFORM=linux DESKTOP=1 link \
  >/dev/null 2>&1 || fail "Linux desktop link failed"
[ -L "$linux_desktop_home/.xsessionrc" ] || \
  fail "Linux desktop link omitted .xsessionrc"
[ -L "$linux_desktop_home/.config/i3/config" ] || \
  fail "Linux desktop link omitted i3"
[ -x "$linux_desktop_home/bin/i3_switch_workspaces.sh" ] || \
  fail "Linux desktop workspace switcher is not executable"
[ -x "$linux_desktop_home/.config/i3/scripts/mediaplayer" ] || \
  fail "Linux desktop media player is not executable"
[ ! -e "$linux_desktop_home/.config/karabiner/karabiner.json" ] || \
  fail "Linux desktop link included macOS config"
assert_no_directory_links "$linux_desktop_home" || \
  fail "Linux desktop link folded directories"

macos_desktop_home=$test_root/macos-desktop-home
mkdir -p "$macos_desktop_home"
run_make "$macos_desktop_home" PLATFORM=macos DESKTOP=1 link \
  >/dev/null 2>&1 || fail "macOS desktop link failed"
[ -L "$macos_desktop_home/.config/karabiner/karabiner.json" ] || \
  fail "macOS desktop link omitted Karabiner"
[ -L "$macos_desktop_home/.config/zsh/sources/osx.zsh" ] || \
  fail "macOS desktop link omitted core macOS shell config"
[ ! -e "$macos_desktop_home/.xsessionrc" ] || \
  fail "macOS desktop link included Linux config"
assert_no_directory_links "$macos_desktop_home" || \
  fail "macOS desktop link folded directories"

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
grep -Fq '.zshenv' "$test_root/conflict-link.log" || \
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
mkdir -p "$repo/vim/.vim/empty-runtime"
run_make "$artifact_home" link >/dev/null 2>&1 || \
  fail "link rejected an empty package directory"
rmdir "$repo/vim/.vim/empty-runtime"

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
ln -s "$repo/git/.gitconfig" "$legacy_home/.gitconfig" || \
  fail "legacy Git config setup failed"
ln -s "$repo/tmux/.tmux.conf" "$legacy_home/.tmux.conf" || \
  fail "legacy tmux config setup failed"
ln -s "$repo/vim/.ideavimrc" "$legacy_home/.ideavimrc" || \
  fail "legacy IdeaVim config setup failed"
mkdir -p "$legacy_home/.funcs"
for name in cpst fzf_sources nav y; do
  ln -s "$repo/scripts/.funcs/$name" "$legacy_home/.funcs/$name" || \
    fail "legacy shell helper setup failed"
done
legacy_log=$test_root/legacy-link.log
if ! run_make "$legacy_home" link > "$legacy_log" 2>&1; then
  cat "$legacy_log" >&2
  fail "legacy migration failed"
fi
[ -d "$legacy_home/.vim" ] && [ ! -L "$legacy_home/.vim" ] || \
  fail "legacy .vim directory remained folded"
[ -f "$legacy_home/.gitconfig" ] && [ ! -L "$legacy_home/.gitconfig" ] || \
  fail "legacy Git config link was not migrated"
[ ! -e "$legacy_home/.tmux.conf" ] && [ ! -L "$legacy_home/.tmux.conf" ] || \
  fail "legacy tmux config link was not removed"
[ -L "$legacy_home/.config/tmux/tmux.conf" ] || \
  fail "legacy tmux config link was not replaced"
[ ! -e "$legacy_home/.funcs" ] || \
  fail "legacy shell helper links were not removed"
[ -L "$legacy_home/.config/shell/functions/cpst" ] || \
  fail "legacy shell helpers were not replaced"
[ ! -e "$legacy_home/.ideavimrc" ] && [ ! -L "$legacy_home/.ideavimrc" ] || \
  fail "legacy IdeaVim config link was not removed"
[ -L "$legacy_home/.config/ideavim/ideavimrc" ] || \
  fail "legacy IdeaVim config link was not replaced"
assert_no_directory_links "$legacy_home" || fail "legacy migration left directory links"

folded_helper_home=$test_root/folded-helper-home
mkdir -p "$folded_helper_home"
ln -s "$repo/scripts/.funcs" "$folded_helper_home/.funcs"
run_make "$folded_helper_home" link >/dev/null 2>&1 || \
  fail "link rejected a folded legacy helper directory"
[ ! -L "$folded_helper_home/.funcs" ] || \
  fail "link left a folded legacy helper directory"
[ -L "$folded_helper_home/.config/shell/functions/cpst" ] || \
  fail "link did not replace folded legacy helpers"

echo "check-link: unrelated shell helpers are preserved"
external_helper_home=$test_root/external-helper-home
mkdir -p "$external_helper_home/.funcs"
ln -s "$test_root/external-helper" "$external_helper_home/.funcs/cpst"
run_make "$external_helper_home" link >/dev/null 2>&1 || \
  fail "link rejected an unrelated helper"
[ "$(readlink "$external_helper_home/.funcs/cpst")" = "$test_root/external-helper" ] || \
  fail "link removed an unrelated helper"

echo "check-link: unrelated IdeaVim config is preserved"
external_ideavim_home=$test_root/external-ideavim-home
mkdir -p "$external_ideavim_home"
ln -s "$test_root/external-ideavimrc" "$external_ideavim_home/.ideavimrc"
run_make "$external_ideavim_home" link >/dev/null 2>&1 || \
  fail "link rejected an unrelated IdeaVim config"
[ "$(readlink "$external_ideavim_home/.ideavimrc")" = "$test_root/external-ideavimrc" ] || \
  fail "link removed an unrelated IdeaVim config"

echo "check-link: existing local Git identity is preserved"
identity_home=$test_root/identity-home
mkdir -p "$identity_home"
printf '[user]\n  email = corp@example.invalid\n' > "$identity_home/.gitconfig"
run_make "$identity_home" link >/dev/null 2>&1 || fail "identity link failed"
grep -q 'corp@example.invalid' "$identity_home/.gitconfig" || \
  fail "link changed an existing local Git config"

echo "check-link: external Git config links are preserved"
linked_identity_home=$test_root/linked-identity-home
linked_identity=$test_root/corporate.gitconfig
mkdir -p "$linked_identity_home"
printf '[user]\n  email = managed@example.invalid\n' > "$linked_identity"
ln -s "$linked_identity" "$linked_identity_home/.gitconfig"
run_make "$linked_identity_home" link >/dev/null 2>&1 || \
  fail "linked identity link failed"
[ "$(readlink "$linked_identity_home/.gitconfig")" = "$linked_identity" ] || \
  fail "link replaced an external Git config link"
grep -q 'managed@example.invalid' "$linked_identity" || \
  fail "link changed an external Git config"

echo "check-link: private agents are explicit and isolated"
private_dir=$test_root/private-agents
private_skill=$private_dir/agents/.agents/skills/corp/SKILL.md
mkdir -p "$(dirname "$private_skill")"
printf '%s\n' '# Corporate skill' > "$private_skill"
git_isolated -C "$private_dir" init -q || fail "private repo init failed"
git_isolated -C "$private_dir" add -Af . || fail "private repo add failed"
git_isolated -C "$private_dir" \
  -c commit.gpgsign=false -c user.name=test -c user.email=test@example.invalid \
  commit -qm private || fail "private repo commit failed"

private_home=$test_root/private-home
mkdir -p "$private_home"
run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" link \
  >/dev/null 2>&1 || fail "private public link failed"
[ ! -e "$private_home/.agents/skills/corp/SKILL.md" ] || \
  fail "public link enabled private agents implicitly"
snapshot_home "$private_home" > "$test_root/private-plan-before"
run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" agents-plan-private \
  >/dev/null 2>&1 || fail "private agent plan failed"
snapshot_home "$private_home" > "$test_root/private-plan-after"
cmp -s "$test_root/private-plan-before" "$test_root/private-plan-after" || \
  fail "private agent plan changed HOME"
run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" agents-enable-private \
  >/dev/null 2>&1 || fail "private agent enable failed"
[ -L "$private_home/.agents/skills/corp/SKILL.md" ] || \
  fail "private agent enable did not link the skill"
assert_no_directory_links "$private_home" || \
  fail "private agent enable folded directories"
[ -z "$(git_isolated -C "$private_dir" status --porcelain)" ] || \
  fail "private agent enable changed its source repo"
snapshot_home "$private_home" > "$test_root/private-before-second"
run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" agents-enable-private \
  >/dev/null 2>&1 || fail "second private agent enable failed"
snapshot_home "$private_home" > "$test_root/private-after-second"
cmp -s "$test_root/private-before-second" "$test_root/private-after-second" || \
  fail "second private agent enable changed HOME"
private_disable_log=$test_root/private-disable.log
if ! run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" \
  agents-disable-private > "$private_disable_log" 2>&1; then
  cat "$private_disable_log" >&2
  fail "private agent disable failed"
fi
[ ! -e "$private_home/.agents/skills/corp/SKILL.md" ] || \
  { cat "$private_disable_log" >&2; fail "private agent disable left the skill"; }
[ -L "$private_home/.agents/AGENTS.md" ] || \
  fail "private agent disable removed the public base"

private_conflict_home=$test_root/private-conflict-home
mkdir -p "$private_conflict_home/.agents/skills/corp"
printf 'keep me\n' > "$private_conflict_home/.agents/skills/corp/SKILL.md"
snapshot_home "$private_conflict_home" > "$test_root/private-conflict-before"
if run_make "$private_conflict_home" PRIVATE_AGENTS_DIR="$private_dir" \
  agents-enable-private > "$test_root/private-conflict.log" 2>&1; then
  fail "private agent enable accepted a conflict"
fi
grep -Fq 'SKILL.md' "$test_root/private-conflict.log" || \
  fail "private agent conflict did not name the path"
snapshot_home "$private_conflict_home" > "$test_root/private-conflict-after"
cmp -s "$test_root/private-conflict-before" "$test_root/private-conflict-after" || \
  fail "private agent conflict changed HOME"

private_artifact=$private_dir/agents/.agents/skills/leak/secret.txt
mkdir -p "$(dirname "$private_artifact")"
printf 'secret\n' > "$private_artifact"
if run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" \
  agents-plan-private > "$test_root/private-artifact.log" 2>&1; then
  fail "private agent plan accepted an untracked artifact"
fi
grep -Fxq '  agents/.agents/skills/leak/' \
  "$test_root/private-artifact.log" || \
  fail "private agent artifact failure did not name the file"
rm -f "$private_artifact"
rmdir "$private_dir/agents/.agents/skills/leak"
mkdir -p "$private_dir/agents/.agents/skills/empty-runtime"
run_make "$private_home" PRIVATE_AGENTS_DIR="$private_dir" \
  agents-plan-private >/dev/null 2>&1 || \
  fail "private agent plan rejected an empty package directory"
rmdir "$private_dir/agents/.agents/skills/empty-runtime"

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
