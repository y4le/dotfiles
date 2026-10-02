#!/bin/sh

set -eu
fail() { echo "check-workspace-picker: $*" >&2; exit 1; }
if ! command -v jq >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail "jq is required"
  echo 'check-workspace-picker: jq absent; skipping outside CI'
  exit 0
fi
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin"
jq_bin=$(command -v jq)
ln -s "$jq_bin" "$test_root/bin/jq"
cat > "$test_root/bin/i3-msg" <<'STUB'
#!/bin/sh
case "$*" in
  '-t get_workspaces')
    [ "${DOTFILES_QUERY_FAIL:-0}" = 0 ] || exit 7
    /bin/cat "$DOTFILES_WORKSPACES" ;;
  *)
    jq -cn --args '$ARGS.positional' "$@" > "$DOTFILES_COMMAND"
    printf '[{"success":%s}]\n' "${DOTFILES_I3_SUCCESS:-true}" ;;
esac
STUB
cat > "$test_root/bin/notify-send" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" > "$DOTFILES_NOTIFICATION"
STUB
for tool in i3-msg notify-send; do chmod +x "$test_root/bin/$tool"; done
cat > "$test_root/workspaces" <<'JSON'
[{"num":-1,"name":"next"},{"num":3,"name":"3, \"quoted\" \\ and ;"},{"num":1,"name":"1 - Term"},{"num":-1,"name":"empty"}]
JSON
run_picker() {
  env -i PATH="$test_root/bin" DOTFILES_WORKSPACES="$test_root/workspaces" \
    DOTFILES_COMMAND="$test_root/command" DOTFILES_NOTIFICATION="$test_root/notification" \
    "$@" /bin/bash "$repo/linux-desktop/.local/bin/i3_switch_workspaces.sh"
}
pick() {
  env -i PATH="$test_root/bin" DOTFILES_WORKSPACES="$test_root/workspaces" \
    DOTFILES_COMMAND="$test_root/command" DOTFILES_NOTIFICATION="$test_root/notification" \
    "$@"
}
picker=$repo/linux-desktop/.local/bin/i3_switch_workspaces.sh

echo 'check-workspace-picker: workspace JSON, names, and row metadata'
run_picker > "$test_root/list"
printf 'empty (new workspace)\000info\037new\nempty\000info\037workspace\nnext\000info\037workspace\n1 - Term\000info\037workspace\n3, "quoted" \\ and ;\000info\037workspace\n' > "$test_root/expected"
cmp "$test_root/list" "$test_root/expected" || fail "picker lost names or action metadata"
pick ROFI_INFO=workspace "$picker" 'empty'
[ "$(cat "$test_root/command")" = '["workspace \"empty\""]' ] || fail "existing empty workspace became action"
pick "$picker" 'next'
[ "$(cat "$test_root/command")" = '["workspace \"next\""]' ] || fail "workspace keyword was not quoted"
pick "$picker" '3, "quoted" \ and ;'
cat > "$test_root/expected-command" <<'JSON'
["workspace \"3, \\\"quoted\\\" \\\\ and ;\""]
JSON
cmp "$test_root/command" "$test_root/expected-command" || fail "i3 command delimiters or escaping changed"
pick ROFI_INFO=new "$picker" 'empty (new workspace)'
[ "$(cat "$test_root/command")" = '["workspace number 2"]' ] || fail "empty action picked an occupied slot"
jq -n '[range(1;11) | {num:.,name:tostring}]' > "$test_root/workspaces"
rm "$test_root/command"
if pick ROFI_INFO=new "$picker" 'empty (new workspace)' 2> "$test_root/error"; then fail "full workspaces accepted"; fi
[ ! -e "$test_root/command" ] || fail "exhaustion sent an i3 command"
grep -q 'all numbered workspaces' "$test_root/notification" || fail "exhaustion was invisible"
printf 'invalid JSON' > "$test_root/workspaces"
if run_picker > /dev/null 2> "$test_root/error"; then fail "malformed JSON accepted"; fi
if run_picker DOTFILES_QUERY_FAIL=1 > /dev/null 2> "$test_root/error"; then fail "IPC query failure accepted"; fi
if pick DOTFILES_I3_SUCCESS=false "$picker" test 2> "$test_root/error"; then fail "i3 rejection accepted"; fi

echo 'check-workspace-picker: ok'
