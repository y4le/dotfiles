#!/bin/sh

set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
data=${DOTFILES_PROFILE_DATA_FILE:-$repo/setup/profiles.yaml}
action=${1:-}
profile=${2-full}
addons=${3:-}
catalog=${DOTFILES_TOOL_CATALOG:-$repo/mise/.config/mise/config.toml}
catalog_tools=$(awk -v action=keys -f "$repo/mk/catalog.awk" "$catalog") || exit 1

case "$action" in
  components|packages|tools|all-packages|all-tools|profiles|packs|pack|tool-users)
    exec awk -v action="$action" -v wanted_profile="$profile" \
      -v addons="$addons" -v catalog_tools="$catalog_tools" -f "$repo/mk/profile.awk" "$data"
    ;;
  validate)
    awk -v action=validate -v catalog_tools="$catalog_tools" -f "$repo/mk/profile.awk" "$data" || exit 1
    packages=$(awk -v action=all-packages -v catalog_tools="$catalog_tools" -f "$repo/mk/profile.awk" "$data") || exit 1
    for package in $packages; do
      if [ ! -d "$repo/$package" ]; then
        echo "profile: missing Stow package: $package" >&2
        exit 1
      fi
    done
    tools=$(awk -v action=all-tools -v catalog_tools="$catalog_tools" -f "$repo/mk/profile.awk" "$data") || exit 1
    configured=$catalog_tools
    for tool in $tools; do
      case " $configured " in
        *" $tool "*) ;;
        *) echo "profile: tool absent from mise config: $tool" >&2; exit 1 ;;
      esac
    done
    for tool in $configured; do
      case " $tools " in
        *" $tool "*) ;;
        *) echo "profile: catalog tool has no pack: $tool" >&2; exit 1 ;;
      esac
    done
    ;;
  *)
    echo "usage: sh mk/profile.sh {components|packages|tools|all-packages|all-tools|profiles|packs|pack|tool-users|validate} [profile] [addons]" >&2
    exit 2
    ;;
esac
