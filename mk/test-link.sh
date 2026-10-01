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
git_isolated -C "$source_repo" ls-files | while IFS= read -r file; do
  [ ! -e "$source_repo/$file" ] && [ ! -L "$source_repo/$file" ] || \
    printf '%s\n' "$file"
done > "$file_list" || exit 1
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
run_make "$fresh_home" link-plan > "$test_root/fresh-plan.log" 2>&1 || \
  fail "fresh link plan failed"
grep -Fq 'LINK: .zshrc => ' "$test_root/fresh-plan.log" || \
  fail "fresh plan hid a new link"
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
[ -d "$fresh_home/.config/herdr" ] && [ ! -L "$fresh_home/.config/herdr" ] || \
  fail "fresh link folded the Herdr config directory"
[ -L "$fresh_home/.config/herdr/config.toml" ] || \
  fail "fresh link did not create the Herdr config"
[ ! -e "$fresh_home/.local/state/herdr" ] || \
  fail "fresh link created Herdr runtime state"
[ -x "$fresh_home/bin/cpy" ] && [ -x "$fresh_home/bin/pst" ] || \
  fail "fresh link did not install clipboard commands"
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
mkdir -p "$fresh_home/.config/herdr/sessions/dev"
printf 'runtime lock\n' > "$fresh_home/.config/herdr/.plugins.lock"
printf 'runtime log\n' > "$fresh_home/.config/herdr/herdr.log"
printf 'runtime socket placeholder\n' > "$fresh_home/.config/herdr/herdr.sock"
printf 'runtime session\n' > "$fresh_home/.config/herdr/sessions/dev/session.json"
assert_no_directory_links "$fresh_home" || fail "fresh link folded directories"
snapshot_home "$fresh_home" > "$test_root/fresh-before"
run_make "$fresh_home" link >/dev/null 2>&1 || fail "second link failed"
snapshot_home "$fresh_home" > "$test_root/fresh-after"
cmp -s "$test_root/fresh-before" "$test_root/fresh-after" || \
  fail "second link changed HOME"
run_make "$fresh_home" link-plan > "$test_root/linked-plan.log" 2>&1 || \
  fail "linked plan failed"
grep -Fqx 'no Stow link changes' "$test_root/linked-plan.log" || \
  fail "linked plan did not summarize restow churn"
if grep -Fq '(reverts previous action)' "$test_root/linked-plan.log"; then
  fail "linked plan showed unchanged restow actions"
fi
run_make "$fresh_home" PLAN_VERBOSE=1 link-plan \
  > "$test_root/verbose-plan.log" 2>&1 || fail "verbose link plan failed"
grep -Fq '(reverts previous action)' "$test_root/verbose-plan.log" || \
  fail "verbose link plan hid Stow's full trace"
rm "$fresh_home/.zshrc" || fail "could not set up a mixed link plan"
run_make "$fresh_home" link-plan > "$test_root/mixed-plan.log" 2>&1 || \
  fail "mixed link plan failed"
grep -Fq 'LINK: .zshrc => ' "$test_root/mixed-plan.log" || \
  fail "mixed plan hid a new link among unchanged links"
if grep -Fq '(reverts previous action)' "$test_root/mixed-plan.log"; then
  fail "mixed plan showed unchanged restow actions"
fi
run_make "$fresh_home" link >/dev/null 2>&1 || \
  fail "could not restore the mixed-plan link"

echo "check-link: desktop packages are opt-in"
linux_core_home=$test_root/linux-core-home
mkdir -p "$linux_core_home"
run_make "$linux_core_home" PLATFORM=linux link \
  >/dev/null 2>&1 || fail "Linux core link failed"
[ ! -e "$linux_core_home/.xsessionrc" ] || \
  fail "Linux core link included desktop config"

macos_core_home=$test_root/macos-core-home
mkdir -p "$macos_core_home"
run_make "$macos_core_home" PLATFORM=macos link-plan > "$test_root/macos-core-plan.log" 2>&1 || \
  fail "macOS core plan failed"
grep -Fq 'LINK: .zprofile => ' "$test_root/macos-core-plan.log" || fail "macOS plan hid the login profile"
run_make "$macos_core_home" PLATFORM=macos link \
  >/dev/null 2>&1 || fail "macOS core link failed"
[ -L "$macos_core_home/.config/zsh/sources/osx.zsh" ] || \
  fail "macOS core link omitted shell config"
[ ! -e "$macos_core_home/.config/karabiner/karabiner.json" ] || \
  fail "macOS core link included desktop config"
[ -L "$macos_core_home/.zprofile" ] || \
  fail "macOS core link omitted login profile"

echo "check-link: existing macOS profile is preserved"
macos_profile_home=$test_root/macos-profile-home
mkdir -p "$macos_profile_home"
printf '%s\n' 'export EXISTING_PROFILE=kept' > "$macos_profile_home/.zprofile"
run_make "$macos_profile_home" PLATFORM=macos link-plan >/dev/null 2>&1 || \
  fail "macOS plan rejected a preservable profile"
[ -f "$macos_profile_home/.zprofile" ] && \
  [ ! -e "$macos_profile_home/.zprofile.local" ] || \
  fail "macOS plan changed existing profile"
run_make "$macos_profile_home" PLATFORM=macos link >/dev/null 2>&1 || \
  fail "macOS link could not preserve existing profile"
[ -L "$macos_profile_home/.zprofile" ] || \
  fail "macOS link omitted managed profile"
grep -Fqx 'export EXISTING_PROFILE=kept' \
  "$macos_profile_home/.zprofile.local" || \
  fail "macOS link changed the preserved profile"
run_make "$macos_profile_home" PLATFORM=macos link >/dev/null 2>&1 || \
  fail "second macOS link failed"
run_make "$macos_profile_home" PLATFORM=macos clean >/dev/null 2>&1 || \
  fail "macOS clean failed"
[ ! -L "$macos_profile_home/.zprofile" ] && \
  grep -Fqx 'export EXISTING_PROFILE=kept' "$macos_profile_home/.zprofile" || \
  fail "macOS clean did not restore the original profile"
[ ! -e "$macos_profile_home/.zprofile.local" ] || fail "restored profile retained its backup path"
run_make "$macos_profile_home" PLATFORM=macos clean >/dev/null 2>&1 || fail "second macOS clean failed"
stray_profile_home=$test_root/stray-profile-home
mkdir -p "$stray_profile_home"
printf 'keep-local\n' > "$stray_profile_home/.zprofile.local"
run_make "$stray_profile_home" PLATFORM=linux clean >/dev/null 2>&1 || fail "clean with a stray local profile failed"
[ ! -e "$stray_profile_home/.zprofile" ] || fail "clean promoted an unrelated local profile"
grep -Fxq keep-local "$stray_profile_home/.zprofile.local" || fail "clean modified an unrelated local profile"

echo "check-link: dangling checkout links are reported without removal"
dangling_home=$test_root/dangling-home
mkdir -p "$dangling_home/.config/zsh/sources"
ln -s ../home/dev/dotfiles/deleted-package/.retired "$dangling_home/.retired"
ln -s "$repo/deleted-package/.config/zsh/sources/missing file.zsh" \
  "$dangling_home/.config/zsh/sources/missing file.zsh"
ln -s "$test_root/external-missing" "$dangling_home/.unrelated"
snapshot_home "$dangling_home" > "$test_root/dangling.before"
run_make "$dangling_home" link-plan > "$test_root/dangling.plan" 2>&1 || fail "dangling link plan failed"
grep -Fq 'DANGLING: .retired => ' "$test_root/dangling.plan" || fail "plan missed a relative dangling link"
grep -Fq 'DANGLING: .config/zsh/sources/missing file.zsh => ' "$test_root/dangling.plan" || \
  fail "plan missed an absolute dangling link with spaces"
if grep -Fq 'DANGLING: .unrelated' "$test_root/dangling.plan"; then fail "plan claimed an unrelated link"; fi
snapshot_home "$dangling_home" > "$test_root/dangling.after"
cmp -s "$test_root/dangling.before" "$test_root/dangling.after" || fail "dangling link plan changed HOME"
mkdir "$dangling_home/.config/unreadable"
chmod 000 "$dangling_home/.config/unreadable"
plan_failed=no
run_make "$dangling_home" link-plan > "$test_root/unreadable.plan" 2>&1 || plan_failed=yes
chmod 700 "$dangling_home/.config/unreadable"
[ "$plan_failed" = no ] || fail "an unreadable unrelated directory blocked link-plan"

macos_profile_conflict_home=$test_root/macos-profile-conflict-home
mkdir -p "$macos_profile_conflict_home"
printf '%s\n' 'first' > "$macos_profile_conflict_home/.zprofile"
printf '%s\n' 'second' > "$macos_profile_conflict_home/.zprofile.local"
if run_make "$macos_profile_conflict_home" PLATFORM=macos link \
  > "$test_root/macos-profile-conflict.log" 2>&1; then
  fail "macOS link overwrote an existing local profile"
fi
grep -Fqx 'first' "$macos_profile_conflict_home/.zprofile" || \
  fail "macOS profile conflict changed original"
grep -Fqx 'second' "$macos_profile_conflict_home/.zprofile.local" || \
  fail "macOS profile conflict changed local backup"

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
grep -Fq '.zshenv' "$test_root/conflict-plan.log" || \
  fail "conflict plan hid the conflicting path"
if run_make "$conflict_home" link-plan > /dev/null 2> "$test_root/conflict-stderr.log"; then
  fail "conflict plan accepted a conflicting HOME with stdout discarded"
fi
grep -Fq '.zshenv' "$test_root/conflict-stderr.log" || \
  fail "conflict plan did not report Stow diagnostics on stderr"
if run_make "$conflict_home" link > "$test_root/conflict-link.log" 2>&1; then
  fail "link accepted a conflicting HOME"
fi
grep -Fq '.zshenv' "$test_root/conflict-link.log" || \
  fail "conflict failure did not name .zshenv"
snapshot_home "$conflict_home" > "$test_root/conflict-after"
cmp -s "$test_root/conflict-before" "$test_root/conflict-after" || \
  fail "conflicting link changed HOME"

echo "check-link: existing Herdr config conflict is non-mutating"
herdr_conflict_home=$test_root/herdr-conflict-home
mkdir -p "$herdr_conflict_home/.config/herdr"
printf 'keep this config\n' > "$herdr_conflict_home/.config/herdr/config.toml"
snapshot_home "$herdr_conflict_home" > "$test_root/herdr-conflict-before"
if run_make "$herdr_conflict_home" _link-plan LINK_PACKAGES=herdr \
  > "$test_root/herdr-conflict-plan.log" 2>&1; then
  fail "link-plan accepted an existing Herdr config"
fi
if run_make "$herdr_conflict_home" _link LINK_PACKAGES=herdr \
  > "$test_root/herdr-conflict-link.log" 2>&1; then
  fail "link accepted an existing Herdr config"
fi
grep -Fq '.config/herdr/config.toml' "$test_root/herdr-conflict-link.log" || \
  fail "Herdr conflict failure did not name config.toml"
snapshot_home "$herdr_conflict_home" > "$test_root/herdr-conflict-after"
cmp -s "$test_root/herdr-conflict-before" "$test_root/herdr-conflict-after" || \
  fail "Herdr config conflict changed HOME"

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
[ -x "$legacy_home/bin/pst" ] || fail "legacy clipboard commands were not installed"
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
[ -x "$folded_helper_home/bin/cpy" ] || fail "link did not install standalone clipboard command"

echo "check-link: retired file-listing helper migration"
retired_helper_home=$test_root/retired-helper-home
mkdir -p "$retired_helper_home/.config/shell/functions"
ln -s "$repo/scripts/.config/shell/functions/fzf_sources" \
  "$retired_helper_home/.config/shell/functions/fzf_sources"
run_make "$retired_helper_home" link >/dev/null 2>&1 || \
  fail "link rejected the retired file-listing helper"
[ ! -L "$retired_helper_home/.config/shell/functions/fzf_sources" ] || \
  fail "link left the retired file-listing helper"
[ -L "$retired_helper_home/bin/filez" ] || fail "link did not install filez"
# Match Stow's relative-link format as well as the absolute fixture above.
helper_link=$(readlink "$retired_helper_home/bin/cpy")
ln -s "../../${helper_link%bin/cpy}.config/shell/functions/fzf_sources" \
  "$retired_helper_home/.config/shell/functions/fzf_sources"
run_make "$retired_helper_home" link >/dev/null 2>&1 || \
  fail "link rejected the relative retired-helper link"
[ ! -L "$retired_helper_home/.config/shell/functions/fzf_sources" ] || \
  fail "link left the relative retired-helper link"

echo "check-link: unused helper links are retired without deleting user files"
for retired in .config/shell/functions/cpst .config/shell/functions/nav bin/compair.sh bin/benchmark.sh; do
  mkdir -p "$retired_helper_home/$(dirname "$retired")"
  ln -s "$repo/scripts/$retired" "$retired_helper_home/$retired"
done
run_make "$retired_helper_home" link >/dev/null 2>&1 || fail "unused helper migration failed"
for retired in .config/shell/functions/cpst .config/shell/functions/nav bin/compair.sh bin/benchmark.sh; do
  [ ! -L "$retired_helper_home/$retired" ] || fail "retired helper link survived: $retired"
  printf 'user helper\n' > "$retired_helper_home/$retired"
done
run_make "$retired_helper_home" link >/dev/null 2>&1 || fail "user-owned retired helper blocked link"
for retired in .config/shell/functions/cpst .config/shell/functions/nav bin/compair.sh bin/benchmark.sh; do
  [ "$(cat "$retired_helper_home/$retired")" = 'user helper' ] || fail "user helper removed: $retired"
done

[ -L "$retired_helper_home/.config/shell/functions/y" ] || fail "link did not restore the active Yazi helper"
run_make "$retired_helper_home" _remove-legacy-functions >/dev/null 2>&1 || fail "legacy cleanup failed"
[ -L "$retired_helper_home/.config/shell/functions/y" ] || fail "legacy cleanup removed active Yazi helper"

echo "check-link: unrelated shell helpers are preserved"
external_helper_home=$test_root/external-helper-home
mkdir -p "$external_helper_home/.funcs" "$external_helper_home/.config/shell/functions"
ln -s "$test_root/external-helper" "$external_helper_home/.config/shell/functions/fzf_sources"
ln -s "$test_root/external-helper" "$external_helper_home/.funcs/cpst"
run_make "$external_helper_home" link >/dev/null 2>&1 || \
  fail "link rejected an unrelated helper"
[ "$(readlink "$external_helper_home/.funcs/cpst")" = "$test_root/external-helper" ] || \
  fail "link removed an unrelated helper"
[ "$(readlink "$external_helper_home/.config/shell/functions/fzf_sources")" = "$test_root/external-helper" ] || \
  fail "link removed an unrelated file-listing helper"
rm "$external_helper_home/.config/shell/functions/fzf_sources"
printf 'user helper\n' > "$external_helper_home/.config/shell/functions/fzf_sources"
run_make "$external_helper_home" _remove-legacy-functions >/dev/null 2>&1 || \
  fail "retired helper cleanup failed with a user-owned file"
[ "$(cat "$external_helper_home/.config/shell/functions/fzf_sources")" = 'user helper' ] || \
  fail "retired helper cleanup removed a user-owned file"

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
mkdir -p "$clean_home/.config/herdr/sessions/dev"
printf 'runtime lock\n' > "$clean_home/.config/herdr/.plugins.lock"
printf 'runtime session\n' > "$clean_home/.config/herdr/sessions/dev/session.json"
run_make "$clean_home" clean >/dev/null 2>&1 || fail "clean failed"
if find "$clean_home" -type l -print | grep -q .; then
  fail "clean left managed links"
fi
[ -f "$clean_home/.config/user-owned" ] || fail "clean removed a user file"
[ ! -e "$clean_home/.config/herdr/config.toml" ] || \
  fail "clean left the managed Herdr config"
[ -f "$clean_home/.config/herdr/.plugins.lock" ] || \
  fail "clean removed the Herdr plugin lock"
[ -f "$clean_home/.config/herdr/sessions/dev/session.json" ] || \
  fail "clean removed Herdr session state"

echo "check-link: local Zsh hook migration"
# $repo is a disposable archive under $test_root; the source checkout is untouched.
mkdir -p "$repo/local/.config/zsh/hooks" "$test_root/local-hook-home"
printf '%s\n' 'export ENV_HOOK_MARKER=legacy' > "$repo/local/.zshenv.local"
printf '%s\n' 'export HOOK_MARKER=legacy' > "$repo/local/.pre_profile"
printf '%s\n' 'export POST_HOOK_MARKER=legacy' > "$repo/local/.post_profile"
printf '%s\n' 'export ENV_HOOK_MARKER=new' > "$repo/local/.config/zsh/hooks/env.zsh"
printf '%s\n' 'export HOOK_MARKER=new' > "$repo/local/.config/zsh/hooks/pre.zsh"
ln -s '../home/dev/dotfiles/local/.zshenv.local' \
  "$test_root/local-hook-home/.zshenv.local"
ln -s '../home/dev/dotfiles/local/.pre_profile' \
  "$test_root/local-hook-home/.pre_profile"
run_make "$test_root/local-hook-home" link \
  > "$test_root/local-hook-link.log" 2>&1 || \
  { cat "$test_root/local-hook-link.log" >&2; fail "local hook migration link failed"; }
[ -L "$test_root/local-hook-home/.config/zsh/hooks/env.zsh" ] || \
  fail "new local Zsh environment hook was not linked"
[ -L "$test_root/local-hook-home/.config/zsh/hooks/pre.zsh" ] || \
  fail "new local Zsh hook was not linked"
[ ! -L "$test_root/local-hook-home/.zshenv.local" ] || \
  fail "old managed Zsh environment hook link was not removed"
[ ! -L "$test_root/local-hook-home/.pre_profile" ] || \
  fail "old managed Zsh hook link was not removed"

mkdir -p "$test_root/zsh-only-hook-home"
ln -s '../home/dev/dotfiles/local/.pre_profile' \
  "$test_root/zsh-only-hook-home/.pre_profile"
run_make "$test_root/zsh-only-hook-home" _link LINK_PACKAGES=zsh \
  >/dev/null 2>&1 || fail "zsh-only link failed"
[ -L "$test_root/zsh-only-hook-home/.pre_profile" ] || \
  fail "zsh-only link removed a local package hook"

# The old package entries have been moved before a user-owned path is tested.
rm -f "$repo/local/.zshenv.local" "$repo/local/.pre_profile"
for kind in file external-link; do
  protected_home=$test_root/local-hook-$kind-home
  mkdir -p "$protected_home"
  if [ "$kind" = file ]; then
    printf '%s\n' 'keep me' > "$protected_home/.pre_profile"
  else
    printf '%s\n' 'keep me' > "$test_root/external-pre-profile"
    ln -s "$test_root/external-pre-profile" "$protected_home/.pre_profile"
  fi
  run_make "$protected_home" link >/dev/null 2>&1 || \
    fail "local hook link failed with a user-owned legacy $kind"
  [ -L "$protected_home/.config/zsh/hooks/pre.zsh" ] || \
    fail "new local Zsh hook was not linked with a user-owned legacy $kind"
  if [ "$kind" = file ]; then
    [ "$(cat "$protected_home/.pre_profile")" = 'keep me' ] || \
      fail "user-owned legacy hook file was changed"
  else
    [ "$(readlink "$protected_home/.pre_profile")" = \
      "$test_root/external-pre-profile" ] || \
      fail "external legacy hook link was changed"
  fi
done

mkdir -p "$test_root/local-hook-fallback-home"
ln -s '../home/dev/dotfiles/local/.post_profile' \
  "$test_root/local-hook-fallback-home/.post_profile"
run_make "$test_root/local-hook-fallback-home" link >/dev/null 2>&1 || \
  fail "legacy local hook fallback link failed"
[ -L "$test_root/local-hook-fallback-home/.post_profile" ] || \
  fail "legacy hook link was removed without a replacement"

printf '%s\n' 'export POST_HOOK_MARKER=new' > \
  "$repo/local/.config/zsh/hooks/post.zsh"
mkdir -p "$test_root/local-post-hook-home"
ln -s '../home/dev/dotfiles/local/.post_profile' \
  "$test_root/local-post-hook-home/.post_profile"
run_make "$test_root/local-post-hook-home" link >/dev/null 2>&1 || \
  fail "local post-hook migration link failed"
[ -L "$test_root/local-post-hook-home/.config/zsh/hooks/post.zsh" ] || \
  fail "new local post hook was not linked"
[ ! -L "$test_root/local-post-hook-home/.post_profile" ] || \
  fail "old managed post-hook link was not removed"

rm -f "$repo/local/.config/zsh/hooks/env.zsh" \
  "$repo/local/.config/zsh/hooks/pre.zsh" \
  "$repo/local/.config/zsh/hooks/post.zsh" \
  "$repo/local/.zshenv.local" "$repo/local/.pre_profile" \
  "$repo/local/.post_profile"
rmdir "$repo/local/.config/zsh/hooks" "$repo/local/.config/zsh" \
  "$repo/local/.config" "$repo/local" 2>/dev/null || :

echo "check-link: profile transitions and saved selection"
profile_home=$test_root/profile-home
mkdir -p "$profile_home/.config/atuin"
printf 'owned\n' > "$profile_home/.config/atuin/notes.txt"
run_make "$profile_home" link >/dev/null 2>&1 || fail "full profile link failed"
[ -L "$profile_home/.config/atuin/config.toml" ] || fail "full omitted Atuin"
[ -L "$profile_home/.config/nvim/init.lua" ] || fail "full omitted Neovim"
[ -L "$profile_home/.config/herdr/config.toml" ] || fail "full omitted Herdr"
snapshot_home "$profile_home" > "$test_root/profile-before-plan"
run_make "$profile_home" PROFILE=lite WITH=yazi link-plan \
  > "$test_root/profile-plan.log" 2>&1 || fail "lite link plan failed"
grep -Fq 'planning removal of unselected add-on links: atuin nvim herdr' \
  "$test_root/profile-plan.log" || fail "lite plan omitted add-on removals"
grep -Fq 'UNLINK: .config/nvim/init.lua' "$test_root/profile-plan.log" || \
  fail "lite plan hid a managed link removal"
snapshot_home "$profile_home" > "$test_root/profile-after-plan"
cmp -s "$test_root/profile-before-plan" "$test_root/profile-after-plan" || \
  fail "lite plan modified HOME"
run_make "$profile_home" PROFILE=lite WITH=yazi link >/dev/null 2>&1 || \
  fail "full to lite transition failed"
[ ! -e "$profile_home/.config/atuin/config.toml" ] || fail "lite left Atuin config"
[ ! -e "$profile_home/.config/nvim/init.lua" ] || fail "lite left Neovim config"
[ ! -e "$profile_home/.config/herdr/config.toml" ] || fail "lite left Herdr config"
[ -L "$profile_home/.zshrc" ] || fail "lite removed core config"
[ -f "$profile_home/.config/atuin/notes.txt" ] || \
  fail "lite removed user-owned Atuin data"
printf 'generated by an old shell hook\n' > "$profile_home/.config/atuin/config.toml"
printf 'another managed Atuin file\n' > "$repo/atuin/.config/atuin/extra.toml"
if run_make "$profile_home" PROFILE=lite WITH=yazi link-plan \
  > "$test_root/atuin-extra-file.log" 2>&1; then
  fail "lite plan skipped Atuin after the package gained another file"
fi
grep -Fq 'package has other files' "$test_root/atuin-extra-file.log" || \
  fail "Atuin package growth did not explain the refusal"
rm "$repo/atuin/.config/atuin/extra.toml"
run_make "$profile_home" PROFILE=lite WITH=yazi link-plan >/dev/null 2>&1 || \
  fail "lite plan rejected a regenerated Atuin config"
run_make "$profile_home" PROFILE=lite WITH=yazi link >/dev/null 2>&1 || \
  fail "lite relink rejected a regenerated Atuin config"
grep -Fqx 'generated by an old shell hook' \
  "$profile_home/.config/atuin/config.toml" || \
  fail "lite relink changed the regenerated Atuin config"
if run_make "$profile_home" PROFILE=full link-plan \
  > "$test_root/atuin-config-conflict.log" 2>&1; then
  fail "full plan accepted a regular Atuin config"
fi
grep -Fq 'move it aside' "$test_root/atuin-config-conflict.log" || \
  fail "Atuin conflict omitted recovery guidance"
mv "$profile_home/.config/atuin/config.toml" "$test_root/generated-atuin-config.toml"
run_make "$profile_home" PROFILE=full link >/dev/null 2>&1 || \
  fail "lite to full transition failed"
[ -L "$profile_home/.config/atuin/config.toml" ] || fail "full did not restore Atuin"
[ -L "$profile_home/.config/nvim/init.lua" ] || fail "full did not restore Neovim"
[ -L "$profile_home/.config/herdr/config.toml" ] || fail "full did not restore Herdr"

run_make "$profile_home" PROFILE=lite WITH='yazi herdr' profile-set \
  >/dev/null 2>&1 || fail "saving profile failed"
saved_profile=$(run_make "$profile_home" profile) || fail "reading saved profile failed"
printf '%s\n' "$saved_profile" | grep -Fqx 'components: core yazi herdr' || \
  fail "saved profile did not select its add-ons"
overridden_profile=$(run_make "$profile_home" PROFILE=full WITH= profile) || \
  fail "command-line profile override failed"
printf '%s\n' "$overridden_profile" | grep -Fqx 'profile: full' || \
  fail "command-line override did not replace saved profile"
if run_make "$profile_home" PROFILE=lite WITH=unknown profile-set \
  >/dev/null 2>&1; then
  fail "invalid saved profile was accepted"
fi
grep -Fqx 'WITH := yazi herdr' "$repo/profile.mk" || \
  fail "invalid profile changed the saved choice"
run_make "$profile_home" PROFILE=lite profile-set >/dev/null 2>&1 || \
  fail "saving lite without add-ons failed"
grep -Fqx 'WITH := ' "$repo/profile.mk" || \
  fail "saving lite kept old add-ons"
run_make "$profile_home" check-make > "$test_root/saved-lite-make.log" 2>&1 || \
  { cat "$test_root/saved-lite-make.log" >&2; fail "check-make failed with saved lite"; }
run_make "$profile_home" check-stow > "$test_root/saved-lite-stow.log" 2>&1 || \
  { cat "$test_root/saved-lite-stow.log" >&2; fail "check-stow failed with saved lite"; }

echo "check-link: recover a stale saved add-on"
printf 'PROFILE := lite\nWITH := retired-component\n' > "$repo/profile.mk"
if run_make "$profile_home" plan > "$test_root/stale-profile.log" 2>&1; then
  fail "plan accepted a stale saved add-on"
fi
grep -Fq 'profile.mk is stale' "$test_root/stale-profile.log" || \
  fail "stale profile error omitted recovery guidance"
if run_make "$profile_home" PROFILE=full profile-set plan \
  > /dev/null 2>&1; then
  fail "mixed goals bypassed stale profile validation"
fi
if run_make "$profile_home" PROFILE=full WITH=retired-component profile-set \
  > /dev/null 2>&1; then
  fail "profile-set accepted an invalid command-line add-on"
fi
grep -Fqx 'WITH := retired-component' "$repo/profile.mk" || \
  fail "invalid profile-set changed the stale choice"
run_make "$profile_home" PROFILE=full profile-set >/dev/null 2>&1 || \
  fail "profile-set could not recover from a stale saved add-on"
grep -Fqx 'PROFILE := full' "$repo/profile.mk" || \
  fail "profile-set did not replace the stale profile"
grep -Fqx 'WITH := ' "$repo/profile.mk" || \
  fail "profile-set retained the stale add-on"
run_make "$profile_home" plan >/dev/null 2>&1 || \
  fail "plan still failed after saved profile recovery"

echo "check-link: clean removes desktop links without DESKTOP=1"
run_make "$linux_desktop_home" PROFILE=lite clean >/dev/null 2>&1 || \
  fail "clean after desktop link failed"
[ ! -e "$linux_desktop_home/.xsessionrc" ] || \
  fail "clean left Linux desktop link"
[ ! -e "$linux_desktop_home/.config/i3/config" ] || \
  fail "clean left i3 link"

echo "check-link: clean preserves a regenerated Atuin config"
run_make "$profile_home" PROFILE=lite WITH= link >/dev/null 2>&1 || \
  fail "could not unlink Atuin before clean test"
printf 'keep this Atuin config\n' > "$profile_home/.config/atuin/config.toml"
run_make "$profile_home" clean >/dev/null 2>&1 || \
  fail "clean rejected a regenerated Atuin config"
[ ! -L "$profile_home/.zshrc" ] || fail "clean left core links behind"
grep -Fqx 'keep this Atuin config' "$profile_home/.config/atuin/config.toml" || \
  fail "clean changed the regenerated Atuin config"

echo "check-link: ok"
