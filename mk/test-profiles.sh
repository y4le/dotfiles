#!/bin/sh

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
[ "$full_tools" = "$lite_tools aqua:atuinsh/atuin aqua:sxyazi/yazi aqua:neovim/neovim go node python rust aqua:astral-sh/uv npm:typescript-language-server pipx:basedpyright pipx:ruff aqua:LuaLS/lua-language-server" ] || \
  fail "full tool set changed: $full_tools"

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

echo "check-profiles: ok"
