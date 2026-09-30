#!/bin/bash

set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
test_root=$(CDPATH='' cd -P "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/home/.config/shell/functions" "$test_root/project" "$test_root/empty"
ln -s "$repo/scripts/.config/shell/functions/fzf_sources" \
  "$test_root/home/.config/shell/functions/fzf_sources"

cd "$test_root/project"
git init -q
printf 'tracked\n' > tracked
printf 'tab\n' > $'tab\tname'
printf 'newline\n' > $'new\nname'
printf 'ignored\n' > ignored
printf 'ignored\n' > .gitignore
git add tracked $'tab\tname' $'new\nname' .gitignore
printf 'new\n' > untracked

HOME="$test_root/home" "$repo/scripts/bin/filez" --print0 > "$test_root/list"
tracked=false
untracked=false
tab=false
newline=false
while IFS= read -r -d '' path; do
  case $path in
    ./tracked) tracked=true ;;
    ./untracked) untracked=true ;;
    $'./tab\tname') tab=true ;;
    $'./new\nname') newline=true ;;
    ./ignored) echo 'check-filez: ignored file listed' >&2; exit 1 ;;
    *) : ;;
  esac
done < "$test_root/list"
if [ "$tracked" != true ] || [ "$untracked" != true ] || \
  [ "$tab" != true ] || [ "$newline" != true ]; then
  echo 'check-filez: missing tracked, new, or special-character filename' >&2
  exit 1
fi

cd "$test_root/empty"
HOME="$test_root/home" "$repo/scripts/bin/filez" --print0 > "$test_root/empty.list"
[ ! -s "$test_root/empty.list" ] || {
  echo 'check-filez: empty directory listed unrelated paths' >&2
  exit 1
}

HOME="$test_root/home" "$repo/scripts/bin/filez" --print0 \
  --root "$test_root/project" > "$test_root/root.list"
absolute=false
while IFS= read -r -d '' path; do
  [ "$path" != "$test_root/project/tracked" ] || absolute=true
done < "$test_root/root.list"
[ "$absolute" = true ] || {
  echo 'check-filez: --root did not emit absolute paths' >&2
  exit 1
}

mkdir -p "$test_root/deleted"
cd "$test_root/deleted"
git init -q
printf 'kept\n' > a
printf 'removed\n' > zzz
git add a zzz
rm zzz
HOME="$test_root/home" "$repo/scripts/bin/filez" --print0 > "$test_root/deleted.list"
count=0
while IFS= read -r -d '' path; do
  [ "$path" != ./a ] || count=$((count + 1))
done < "$test_root/deleted.list"
[ "$count" -eq 1 ] || {
  echo 'check-filez: deleted Git entry caused duplicate results' >&2
  exit 1
}

cd "$test_root"
CDPATH="$test_root" HOME="$test_root/home" \
  "$repo/scripts/bin/filez" --print0 --root project > "$test_root/cdpath.list"
absolute=false
while IFS= read -r -d '' path; do
  [ "$path" != "$test_root/project/tracked" ] || absolute=true
done < "$test_root/cdpath.list"
[ "$absolute" = true ] || {
  echo 'check-filez: CDPATH corrupted --root paths' >&2
  exit 1
}

echo 'check-filez: partial source errors never replay the listing'
partial_bin=$test_root/partial-bin
mkdir -p "$partial_bin"
cat > "$partial_bin/rg" <<'EOF'
#!/bin/sh
printf './partial\000'
exit 2
EOF
cat > "$partial_bin/fd" <<'EOF'
#!/bin/sh
printf './duplicate\000'
printf fallback >> "$DOTFILES_FALLBACK_LOG"
exit 1
EOF
cat > "$partial_bin/find" <<'EOF'
#!/bin/sh
printf './duplicate\000'
printf fallback >> "$DOTFILES_FALLBACK_LOG"
EOF
chmod +x "$partial_bin/rg" "$partial_bin/fd" "$partial_bin/find"
: > "$test_root/fallback.log"
PATH="$partial_bin" HOME="$test_root/home" DOTFILES_FALLBACK_LOG="$test_root/fallback.log" \
  "$repo/scripts/bin/filez" --print0 > "$test_root/partial.list"
expected=./partial
IFS= read -r -d '' actual < "$test_root/partial.list" || true
[ "$actual" = "$expected" ] && [ "$(wc -c < "$test_root/partial.list")" -eq 10 ] || {
  echo 'check-filez: partial rg result was changed or duplicated' >&2; exit 1;
}
[ ! -s "$test_root/fallback.log" ] || { echo 'check-filez: rg error triggered fallback' >&2; exit 1; }
rm "$partial_bin/rg"
if PATH="$partial_bin" HOME="$test_root/home" DOTFILES_FALLBACK_LOG="$test_root/fallback.log" \
  "$repo/scripts/bin/filez" --print0 > "$test_root/partial-fd.list"; then
  echo 'check-filez: fd failure status was lost' >&2; exit 1
fi
[ "$(cat "$test_root/fallback.log")" = fallback ] || {
  echo 'check-filez: partial fd failure also invoked find' >&2; exit 1;
}
rm "$partial_bin/fd"
: > "$test_root/fallback.log"
PATH="$partial_bin" HOME="$test_root/home" DOTFILES_FALLBACK_LOG="$test_root/fallback.log" \
  "$repo/scripts/bin/filez" --print0 > "$test_root/find.list"
[ "$(cat "$test_root/fallback.log")" = fallback ] || {
  echo 'check-filez: missing rg and fd did not use find' >&2; exit 1;
}

echo 'check-filez: ok'
