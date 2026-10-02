#!/bin/bash

set -o pipefail
fail() {
  printf 'workspace picker: %s\n' "$*" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send 'Workspace picker' "$*" >/dev/null 2>&1 || true
  fi
  exit 1
}
command -v jq >/dev/null 2>&1 || fail "jq is required; run make system-packages"
(( $# <= 1 )) || fail "expected at most one workspace name"

if (( $# == 0 )) || [[ ${ROFI_INFO:-} = new ]]; then
  workspaces=$(i3-msg -t get_workspaces) || fail "could not read i3 workspaces"
  jq -e 'type == "array" and all(.[]; (.num | type) == "number" and (.name | type) == "string" and (.name | contains("\n") or contains("\r") | not))' \
    <<< "$workspaces" >/dev/null || fail "invalid i3 workspace response"
  if (( $# == 0 )); then
    # Rofi row metadata distinguishes the action from a workspace named empty.
    printf 'empty (new workspace)\0info\x1fnew\n'
    jq -r 'sort_by(.num, .name)[] | .name + "\u0000info\u001fworkspace"' <<< "$workspaces"
    exit
  fi
  number=$(jq -r '[.[].num] as $used | [range(1;11) | select(. as $n | $used | index($n) | not)][0] // empty' \
    <<< "$workspaces") || fail "could not find an unused workspace"
  [[ -n $number ]] || fail "all numbered workspaces (1-10) are in use"
  command_text="workspace number $number"
else
  name=$1
  [[ -n $name && $name != *$'\n'* && $name != *$'\r'* ]] || fail "workspace name must be one nonempty line"
  # Escape for i3's command parser, independently of shell argument quoting.
  name=${name//\\/\\\\}
  name=${name//\"/\\\"}
  command_text="workspace \"$name\""
fi
reply=$(i3-msg "$command_text") || fail "i3 workspace command failed"
jq -e 'type == "array" and length > 0 and all(.[]; .success == true)' \
  <<< "$reply" >/dev/null || fail "i3 rejected the workspace command"
