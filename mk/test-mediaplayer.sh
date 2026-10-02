#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu
fail() { echo "check-mediaplayer: $*" >&2; exit 1; }
repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
trap 'rm -rf "$test_root"; exit 1' HUP INT TERM
mkdir -p "$test_root/bin"
cat > "$test_root/bin/playerctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$DOTFILES_MEDIA_LOG"
[ "${DOTFILES_NO_PLAYER:-0}" = 0 ] || exit 1
if [ "$2" != metadata ] && [ "${DOTFILES_ACTION_FAIL:-0}" = 1 ]; then exit 7; fi
case $2 in
  metadata)
    [ "$3" = --format ] || exit 8
    printf '%s\037%s\n' "${DOTFILES_ARTIST-Artist}" "${DOTFILES_TITLE-Title}" ;;
esac
STUB
cat > "$test_root/bin/sleep" <<'STUB'
#!/bin/sh
printf 'sleep %s\n' "$*" >> "$DOTFILES_MEDIA_LOG"
STUB
for tool in playerctl sleep; do chmod +x "$test_root/bin/$tool"; done
echo 'check-mediaplayer: media fields, buttons, and absent dependencies'
media=$repo/linux-desktop/.config/i3/scripts/mediaplayer
run_media() {
  : > "$test_root/media-log"
  env -i PATH="$test_root/bin" DOTFILES_MEDIA_LOG="$test_root/media-log" "$@" "$media"
}
run_media > "$test_root/media"
printf 'Artist - Title\n' > "$test_root/expected"
cmp "$test_root/media" "$test_root/expected" || fail "media output has extra newlines"
run_media BLOCK_BUTTON=1 DOTFILES_ACTION_FAIL=1 > "$test_root/media"
cmp "$test_root/media" "$test_root/expected" || fail "failed action blanked valid metadata"
run_media DOTFILES_ARTIST= DOTFILES_TITLE=Podcast > "$test_root/media"
[ "$(cat "$test_root/media")" = Podcast ] || fail "missing artist left a separator"
run_media DOTFILES_ARTIST= DOTFILES_TITLE= > "$test_root/media"
[ ! -s "$test_root/media" ] || fail "empty metadata became text"
for button in 1 2 3 4 5; do
  case $button in
    1) expected=previous ;; 2) expected=play-pause ;; 3) expected=next ;;
    4) expected='volume 0.01+' ;; 5) expected='volume 0.01-' ;;
  esac
  run_media BLOCK_BUTTON="$button" > "$test_root/media"
  grep -Fx -- "--player=spotify $expected" "$test_root/media-log" >/dev/null || fail "button $button changed action"
  case $button in
    1|3) grep -Fx 'sleep 0.05' "$test_root/media-log" >/dev/null || fail "Spotify delay lost" ;;
  esac
done
run_media BLOCK_INSTANCE=vlc > "$test_root/media"
grep -q '^--player=vlc metadata' "$test_root/media-log" || fail "player instance ignored"
run_media DOTFILES_NO_PLAYER=1 > "$test_root/media"
[ ! -s "$test_root/media" ] || fail "absent player became bar text"
rm "$test_root/bin/playerctl"
if run_media > "$test_root/media" 2> "$test_root/error"; then fail "missing playerctl accepted"; fi
grep -Fx '[missing playerctl]' "$test_root/media" >/dev/null || fail "missing dependency invisible"
echo 'check-mediaplayer: ok'
