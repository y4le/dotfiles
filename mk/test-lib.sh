#!/bin/sh

# Shared lifecycle for tests whose only persistent resource is test_root.
# Callers retain their own shell options, fixtures, and assertions.
test_init() {
  test_label=$1
  test_root=$(mktemp -d) || exit 1
  trap test_cleanup EXIT
  trap 'exit 1' HUP INT TERM
}

test_cleanup() {
  rm -rf "$test_root"
}

fail() {
  echo "$test_label: $*" >&2
  exit 1
}
