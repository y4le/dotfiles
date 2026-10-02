#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

fail() {
  echo "check-profiles: $*" >&2
  exit 1
}

echo "check-profiles: validate profile data against packages and mise pins"
sh mk/profile.sh validate || fail "profile validation failed"

lite_packages=$(sh mk/profile.sh packages lite) || fail "lite packages did not resolve"
[ "$lite_packages" = "agents bash git mise scripts tmux vim zsh" ] || \
  fail "lite package set changed: $lite_packages"

lite_tools=$(sh mk/profile.sh tools lite) || fail "lite tools did not resolve"
[ "$lite_tools" = "aqua:junegunn/fzf aqua:BurntSushi/ripgrep aqua:sharkdp/bat aqua:dandavison/delta aqua:ajeetdsouza/zoxide" ] || \
  fail "lite tool set changed: $lite_tools"

full_packages=$(sh mk/profile.sh packages full) || fail "full packages did not resolve"
expected_full=$(printf '%s\n' agents atuin bash git herdr mise nvim scripts tmux vim zsh | sort)
actual_full=$(printf '%s\n' $full_packages | sort)
[ "$actual_full" = "$expected_full" ] || fail "full package set differs from the old default"

full_tools=$(sh mk/profile.sh tools full) || fail "full tools did not resolve"
[ "$full_tools" = "$lite_tools aqua:atuinsh/atuin aqua:sxyazi/yazi aqua:neovim/neovim node aqua:LuaLS/lua-language-server" ] || \
  fail "full tool set changed: $full_tools"
legacy_full="$lite_tools aqua:atuinsh/atuin aqua:sxyazi/yazi aqua:neovim/neovim go node python rust aqua:astral-sh/uv npm:typescript-language-server pipx:basedpyright pipx:ruff aqua:LuaLS/lua-language-server"
[ "$(sh mk/profile.sh tools full dev)" = "$legacy_full" ] || fail 'dev compatibility lost old defaults'
[ "$(sh mk/profile.sh tools full 'web-dev python-dev go-dev rust-dev')" = "$legacy_full" ] || \
  fail 'individual development packs differ from the compatibility bundle'
[ "$(sh mk/profile.sh tools lite node)" = "$lite_tools node" ] || fail 'Node pack pulls development tools'
[ "$(sh mk/profile.sh tools lite python-dev)" = "$lite_tools python aqua:astral-sh/uv pipx:basedpyright pipx:ruff" ] || \
  fail 'Python pack lost its runtime prerequisites or leaked other languages'
[ "$(sh mk/profile.sh tools full node)" = "$full_tools" ] || \
  fail 'redundant Node selection changed full tool membership'
sh mk/profile.sh tool-users full dev | grep -Fxq 'aqua:LuaLS/lua-language-server: nvim dev' || \
  fail 'Lua server shared ownership is wrong'

with_packages=$(sh mk/profile.sh packages lite 'nvim herdr') || fail "add-on packages did not resolve"
[ "$with_packages" = "$lite_packages nvim herdr" ] || \
  fail "add-ons did not extend lite packages: $with_packages"
with_tools=$(sh mk/profile.sh tools lite 'yazi yazi') || fail "add-on tools did not resolve"
[ "$with_tools" = "$lite_tools aqua:sxyazi/yazi" ] || \
  fail "repeated add-on changed tool selection: $with_tools"
dev_tools=$(sh mk/profile.sh tools lite dev) || fail "dev tools did not resolve"
case " $dev_tools " in
  *' aqua:astral-sh/uv '*' pipx:basedpyright pipx:ruff '*) ;;
  *) fail "dev tools do not install uv before pipx tools: $dev_tools" ;;
esac

echo "check-profiles: reject unknown selections and malformed YAML"
if sh mk/profile.sh components '' > /dev/null 2>&1; then
  fail "empty profile was accepted"
fi
if empty_profile=$(make -n PROFILE= WITH= profile-set 2>&1); then
  fail "Make accepted an empty saved profile"
fi
printf '%s\n' "$empty_profile" | grep -F 'unknown profile:' >/dev/null || \
  fail "empty saved profile failed for an unrelated reason: $empty_profile"
if sh mk/profile.sh components unknown > /dev/null 2>&1; then
  fail "unknown profile was accepted"
fi
for addon in unknown rclone; do
  if sh mk/profile.sh components lite "$addon" > /dev/null 2>&1; then
    fail "unknown or retired add-on was accepted: $addon"
  fi
done

echo "check-profiles: desktop selection requires a Make argument"
ambient_packages=$(MAKEFLAGS='' MFLAGS='' MAKEOVERRIDES='' DESKTOP=1 \
  make -s PROFILE=lite WITH= PLATFORM=linux _print-packages) || \
  fail "ambient desktop selection failed"
case " $ambient_packages " in
  *' linux-desktop '*) fail "ambient DESKTOP selected desktop packages" ;;
esac
explicit_packages=$(MAKEFLAGS='' MFLAGS='' MAKEOVERRIDES='' DESKTOP=0 \
  make -s PROFILE=lite WITH= PLATFORM=linux DESKTOP=1 _print-packages) || \
  fail "explicit desktop selection failed"
case " $explicit_packages " in
  *' linux-desktop '*) ;;
  *) fail "explicit DESKTOP did not select desktop packages" ;;
esac

test_root=$(mktemp -d) || exit 1
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
cat > "$test_root/bad.yaml" <<'EOF'
components:
  core:
    summary: Test core
    packages: [agents]
    tools: [aqua:junegunn/fzf]
profiles:
  lite: [core]
  full: [core]
  extra: &core [core]
EOF
if DOTFILES_PROFILE_DATA_FILE="$test_root/bad.yaml" \
  sh mk/profile.sh components lite > /dev/null 2>&1; then
  fail "unsupported YAML syntax was accepted"
fi

echo "check-profiles: shared runtimes, optional catalog entries and stable ordering"
awk '
  /^profiles:/ {
    print "  test-node:"
    print "    summary: Standalone Node runtime"
    print "    tools: [node]"
    print "  test-web:"
    print "    summary: Web development"
    print "    tools: [node, npm:typescript-language-server]"
  }
  { print }
' setup/profiles.yaml > "$test_root/shared.yaml"
fixture_profile() {
  DOTFILES_PROFILE_DATA_FILE="$test_root/shared.yaml" sh mk/profile.sh "$@"
}
fixture_profile validate || fail "shared tools or optional packs were rejected"
first=$(fixture_profile tools lite 'test-node test-web') || fail "shared tools did not resolve"
second=$(fixture_profile tools lite 'test-web test-node') || fail "reverse selection failed"
[ "$first" = "$second" ] || fail "tool order depends on WITH order"
[ "$first" = "$lite_tools node npm:typescript-language-server" ] || \
  fail "shared runtime was duplicated or ordered incorrectly: $first"
retained=$(fixture_profile tools lite test-node) || fail "runtime retention failed"
[ "$retained" = "$lite_tools node" ] || fail "deselecting web-dev lost the shared runtime"
[ "$(fixture_profile tools lite '')" = "$lite_tools" ] || fail "optional tools leaked into lite"
fixture_profile packs | grep -Eq '^test-node +optional +Standalone Node runtime$' || \
  fail "optional pack discovery omitted preset status"
fixture_profile pack test-web | grep -Fq 'mise tools: node npm:typescript-language-server' || \
  fail "pack description omitted its direct tools"
fixture_profile tool-users lite 'test-node test-web' | grep -Fxq 'node: test-node test-web' || \
  fail "shared-tool attribution is wrong"
sed 's/tools: \[node, npm:typescript-language-server\]/tools: [npm:typescript-language-server]/' \
  "$test_root/shared.yaml" > "$test_root/missing-node.yaml"
if DOTFILES_PROFILE_DATA_FILE="$test_root/missing-node.yaml" sh mk/profile.sh validate >/dev/null 2>&1; then
  fail "npm pack without its Node runtime was accepted"
fi
awk '{ print; if ($0 == "    summary: Standalone Node runtime") print "    packages: [nvim]" }' \
  "$test_root/shared.yaml" > "$test_root/duplicate-owner.yaml"
if DOTFILES_PROFILE_DATA_FILE="$test_root/duplicate-owner.yaml" sh mk/profile.sh validate >"$test_root/duplicate-owner.log" 2>&1; then
  fail "duplicate Stow ownership was accepted"
fi
grep -Fq "package nvim belongs to multiple components" "$test_root/duplicate-owner.log" || \
  fail "duplicate-owner fixture failed for an unrelated reason"
cp setup/tools.toml "$test_root/unowned.toml"
printf 'unowned = "1.0.0"\n' >> "$test_root/unowned.toml"
if DOTFILES_TOOL_CATALOG="$test_root/unowned.toml" sh mk/profile.sh validate >"$test_root/unowned.log" 2>&1; then
  fail "unreferenced catalog key was accepted"
fi
grep -Fq "catalog tool has no pack: unowned" "$test_root/unowned.log" || fail 'unowned fixture failed for an unrelated reason'
if make -n PROFILE=full profile-set >/dev/null 2>&1; then
  fail "profile-set accepted missing WITH"
fi
if make -n WITH= profile-set >/dev/null 2>&1; then
  fail "profile-set accepted missing PROFILE"
fi

echo "check-profiles: unsupported tool subtables fail instead of disappearing"
cp setup/tools.toml "$test_root/subtable.toml"
printf '\n[tools.extra]\nversion = "1.0.0"\n' >> "$test_root/subtable.toml"
if DOTFILES_TOOL_CATALOG="$test_root/subtable.toml" sh mk/profile.sh validate >"$test_root/subtable.log" 2>&1; then
  fail "catalog silently ignored a tool subtable"
fi
grep -Fq 'tool subtables' "$test_root/subtable.log" || fail 'subtable rejection failed for an unrelated reason'
if command -v busybox >/dev/null 2>&1; then
  busybox awk -v action=validate -v catalog_tools="$(sh mk/profile.sh all-tools)" \
    -f mk/profile.awk setup/profiles.yaml || fail 'profile parser is not portable to busybox awk'
fi

echo "check-profiles: ok"
