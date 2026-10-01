#!/bin/sh

set -eu
repo=$1
profile=$2
addons=$3
target=$repo/profile.mk
old_profile=full
old_addons=
if [ -f "$target" ]; then
  old_profile=$(sed -n 's/^PROFILE := //p' "$target")
  old_addons=$(sed -n 's/^WITH := //p' "$target")
fi
printf 'previous: profile=%s add-ons=%s\n' "$old_profile" "${old_addons:-none}"
printf 'new: profile=%s add-ons=%s\n' "$profile" "${addons:-none}"
new=$(sh "$repo/mk/profile.sh" components "$profile" "$addons") || exit 1
if old=$(sh "$repo/mk/profile.sh" components "$old_profile" "$old_addons" 2>/dev/null); then
  dropped=
  for pack in $old; do
    case " $new " in
      *" $pack "*) ;;
      *) dropped="${dropped:+$dropped }$pack" ;;
    esac
  done
  printf 'dropped packs: %s\n' "${dropped:-none}"
else
  echo 'previous selection is stale; replacing it with the complete new selection'
fi
umask 077
tmp=$(mktemp "$target.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
printf 'PROFILE := %s\nWITH := %s\n' "$profile" "$addons" > "$tmp"
mv "$tmp" "$target"
echo "saved selection in $target"
echo "run 'make plan' to preview its setup"
