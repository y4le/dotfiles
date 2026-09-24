#!/usr/bin/env bash

# Usage: benchmark.sh [-n runs] -- command [args...]
set -u

runs=10
while (($#)); do
  case $1 in
    -n)
      (($# >= 2)) || { echo 'benchmark: -n needs a value' >&2; exit 2; }
      runs=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *) break ;;
  esac
done

[[ $runs =~ ^[1-9][0-9]*$ ]] || {
  echo 'benchmark: runs must be a positive integer' >&2
  exit 2
}
(($#)) || { echo 'benchmark: command required' >&2; exit 2; }

tmpdir=$(mktemp -d) || exit 1
trap 'rm -r "$tmpdir"' EXIT
times=$tmpdir/times
: > "$times"
TIMEFORMAT='%R'

printf 'N: %d  cmd:' "$runs"
printf ' %q' "$@"
printf '\n'

for ((i = 1; i <= runs; i++)); do
  { time "$@" > /dev/null 2> "$tmpdir/command.err"; } 2> "$tmpdir/time"
  rc=$?
  cat "$tmpdir/command.err" >&2
  if ((rc != 0)); then
    printf 'benchmark: run %d failed (exit %d)\n' "$i" "$rc" >&2
    exit "$rc"
  fi
  cat "$tmpdir/time" >> "$times"
  printf '\r%d/%d' "$i" "$runs" >&2
done
printf '\n' >&2

LC_ALL=C awk '
  { elapsed = $1; sub(/,/, ".", elapsed); elapsed += 0 }
  NR == 1 { min = max = elapsed }
  elapsed < min { min = elapsed }
  elapsed > max { max = elapsed }
  { total += elapsed }
  END {
    printf "total: %.3f  avg: %.3f  min: %.3f  max: %.3f\n",
      total, total / NR, min, max
  }
' "$times"
