#!/bin/sh

set -eu

verbose=$1
shift

# Preserve Stow's complete diagnostics when its dry run finds a conflict.
if output=$("$@" 2>&1); then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi

if [ "$verbose" = 1 ]; then
  printf '%s\n' "$output"
else
  printf '%s\n' "$output" | awk -f "$(dirname "$0")/stow-plan.awk"
fi
