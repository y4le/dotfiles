#!/bin/sh

set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
data=${DOTFILES_PROFILE_DATA_FILE:-$repo/setup/profiles.yaml}
action=${1:-}
profile=${2:-full}
addons=${3:-}

case "$action" in
  components|packages|tools|all-packages|all-tools|profiles)
    exec awk -v action="$action" -v wanted_profile="$profile" \
      -v addons="$addons" -f "$repo/mk/profile.awk" "$data"
    ;;
  validate)
    awk -v action=validate -f "$repo/mk/profile.awk" "$data" || exit 1
    packages=$(awk -v action=all-packages -f "$repo/mk/profile.awk" "$data") || exit 1
    for package in $packages; do
      if [ ! -d "$repo/$package" ]; then
        echo "profile: missing Stow package: $package" >&2
        exit 1
      fi
    done
    tools=$(awk -v action=all-tools -f "$repo/mk/profile.awk" "$data") || exit 1
    configured=$(awk '
      /^\[tools\]$/ { in_tools = 1; next }
      /^\[/ { in_tools = 0 }
      in_tools && /^[[:space:]]*("[^"]+"|[A-Za-z0-9_-]+)[[:space:]]*=/ {
        key = $0
        sub(/[[:space:]]*=.*/, "", key)
        gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", key)
        printf "%s%s", (seen++ ? " " : ""), key
      }
    ' "$repo/mise/.config/mise/config.toml") || exit 1
    for tool in $tools; do
      case " $configured " in
        *" $tool "*) ;;
        *) echo "profile: tool absent from mise config: $tool" >&2; exit 1 ;;
      esac
    done
    for tool in $configured; do
      case " $tools " in
        *" $tool "*) ;;
        *) echo "profile: mise tool has no component: $tool" >&2; exit 1 ;;
      esac
    done
    ;;
  *)
    echo "usage: sh mk/profile.sh {components|packages|tools|all-packages|all-tools|profiles|validate} [profile] [addons]" >&2
    exit 2
    ;;
esac
