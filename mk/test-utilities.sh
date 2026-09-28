#!/bin/sh
set -eu

fail() {
  echo "check-utilities: $*" >&2
  exit 1
}

repo=$(pwd -P)
test_root=$(mktemp -d) || exit 1
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P) || exit 1
trap 'rm -r "$test_root"' EXIT HUP INT TERM

echo 'check-utilities: benchmark command arguments, timing and failure'
cat > "$test_root/work" <<'EOF'
#!/bin/sh
[ "${LC_ALL-}" = POSIX ] || exit 24
[ "$1" = 'argument with spaces' ] || exit 23
count=$(wc -l < "$DOTFILES_TEST_COUNT")
printf '%s\n' "$1" >> "$DOTFILES_TEST_COUNT"
case $count in
  0) sleep 0.06 ;;
  1) sleep 0.01 ;;
  2) sleep 0.03 ;;
esac
EOF
chmod +x "$test_root/work"
: > "$test_root/count"
LC_ALL=POSIX DOTFILES_TEST_COUNT="$test_root/count" \
  bash "$repo/scripts/bin/benchmark.sh" \
  -n 3 -- "$test_root/work" 'argument with spaces' \
  > "$test_root/benchmark.out" 2> "$test_root/benchmark.err" || \
  fail 'benchmark rejected a valid command'
[ "$(wc -l < "$test_root/count")" -eq 3 ] || \
  fail 'benchmark did not run the whole command three times'
[ "$(grep -Fxc 'argument with spaces' "$test_root/count")" -eq 3 ] || \
  fail 'benchmark changed a command argument'
awk '
  /^total:/ {
    if ($2 <= 0 || $6 >= $8 || $6 > $4 || $4 > $8) exit 1
    found = 1
  }
  END { if (!found) exit 1 }
' "$test_root/benchmark.out" || \
  fail 'benchmark timings have invalid min, average or max'
if bash "$repo/scripts/bin/benchmark.sh" -n 0 -- true \
  > "$test_root/invalid.out" 2>&1; then
  fail 'benchmark accepted zero runs'
fi
if bash "$repo/scripts/bin/benchmark.sh" -n 3 -- sh -c 'exit 7' \
  > "$test_root/failure.out" 2>&1; then
  fail 'benchmark hid a command failure'
fi
grep -Fq 'run 1 failed (exit 7)' "$test_root/failure.out" || \
  fail 'benchmark did not report the failing run'

if ! command -v vim >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail 'Vim required in CI'
  echo 'check-utilities: skipping compair without Vim'
  exit 0
fi

echo 'check-utilities: compair opens exact file pairs in Vim'
vim_bin=$(command -v vim)
cat > "$test_root/vim" <<'EOF'
#!/bin/sh
[ "$1" = -S ] || exit 98
script=$2
shift 2
[ "$1" = -- ] || exit 99
shift
exec "$DOTFILES_TEST_VIM_BIN" -Nu NONE -i NONE -n -es -S "$script" \
  -c 'call writefile([string(tabpagenr("$")),bufname(tabpagebuflist(1)[0]),bufname(tabpagebuflist(1)[1]),bufname(tabpagebuflist(2)[0]),bufname(tabpagebuflist(2)[1])], expand("$DOTFILES_TEST_REPORT"))' \
  -c 'qa!' \
  -- "$@"
EOF
chmod +x "$test_root/vim"
for name in 'one space.txt' "two's.txt" three.txt four.txt; do
  printf '%s\n' "$name" > "$test_root/$name"
done
DOTFILES_TEST_VIM_BIN="$vim_bin" DOTFILES_TEST_REPORT="$test_root/report" \
  PATH="$test_root:$PATH" bash "$repo/scripts/bin/compair.sh" \
  "$test_root/one space.txt" "$test_root/two's.txt" \
  "$test_root/three.txt" "$test_root/four.txt" \
  > "$test_root/compair.out" 2> "$test_root/compair.err" || \
  fail 'compair failed with spaces or apostrophes in file names'
[ "$(sed -n '1p' "$test_root/report")" = 2 ] || \
  fail 'compair did not create one tab per pair'
[ "$(wc -l < "$test_root/report")" -eq 5 ] || \
  fail 'compair created the wrong number of diff windows'
first_pair=$(sed -n '2,3p' "$test_root/report" | LC_ALL=C sort)
expected_first=$(printf '%s\n' "$test_root/one space.txt" \
  "$test_root/two's.txt" | LC_ALL=C sort)
[ "$first_pair" = "$expected_first" ] || \
  fail 'compair placed the wrong files in the first tab'
second_pair=$(sed -n '4,5p' "$test_root/report" | LC_ALL=C sort)
expected_second=$(printf '%s\n' "$test_root/three.txt" \
  "$test_root/four.txt" | LC_ALL=C sort)
[ "$second_pair" = "$expected_second" ] || \
  fail 'compair placed the wrong files in the second tab'
if bash "$repo/scripts/bin/compair.sh" "$test_root/one space.txt" \
  > "$test_root/odd.out" 2>&1; then
  fail 'compair accepted an unmatched file'
fi

echo 'check-utilities: ok'
