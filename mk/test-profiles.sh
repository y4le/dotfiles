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
[ "$lite_tools" = "aqua:junegunn/fzf aqua:BurntSushi/ripgrep aqua:sharkdp/fd aqua:sharkdp/bat aqua:dandavison/delta aqua:ajeetdsouza/zoxide" ] || \
  fail "lite tool set changed: $lite_tools"

full_packages=$(sh mk/profile.sh packages full) || fail "full packages did not resolve"
expected_full=$(printf '%s\n' agents atuin bash git herdr mise nvim scripts tmux vim zsh | sort)
actual_full=$(printf '%s\n' $full_packages | sort)
[ "$actual_full" = "$expected_full" ] || fail "full package set differs from the old default"

with_packages=$(sh mk/profile.sh packages lite 'nvim herdr') || fail "add-on packages did not resolve"
[ "$with_packages" = "$lite_packages nvim herdr" ] || \
  fail "add-ons did not extend lite packages: $with_packages"
with_tools=$(sh mk/profile.sh tools lite 'yazi yazi') || fail "add-on tools did not resolve"
[ "$with_tools" = "$lite_tools aqua:sxyazi/yazi" ] || \
  fail "repeated add-on changed tool selection: $with_tools"

echo "check-profiles: reject unknown selections and malformed YAML"
if sh mk/profile.sh components unknown > /dev/null 2>&1; then
  fail "unknown profile was accepted"
fi
if sh mk/profile.sh components lite unknown > /dev/null 2>&1; then
  fail "unknown add-on was accepted"
fi

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
