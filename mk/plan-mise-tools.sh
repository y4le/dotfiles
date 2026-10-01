#!/bin/sh

# Read-only inventory against the catalog, independently of active HOME pins.
set -eu
repo=$1
mise_bin=$2
catalog=$3
selected=$4
keys=$(awk -v action=keys -f "$repo/mk/catalog.awk" "$catalog")
echo "Installation inventory uses catalog pins; project/local overrides apply at runtime."
if [ ! -x "$mise_bin" ]; then
  echo 'tool installations: mise unavailable; run make setup-user to restore selected tools'
  exit 0
fi
export MISE_OFFLINE=1 MISE_AUTO_INSTALL=false MISE_EXEC_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false
export MISE_CEILING_PATHS="$repo" MISE_GLOBAL_CONFIG_FILE="$catalog"
cd "$repo"
missing=
unselected=
for key in $keys; do
  case " $selected " in
    *" $key "*)
      location=$("$mise_bin" where "$key" </dev/null 2>/dev/null || true)
      if [ -z "$location" ] || [ ! -d "$location" ]; then missing="$missing $key"; fi
      ;;
    *)
      installed=$("$mise_bin" ls --installed --no-header "$key" </dev/null 2>/dev/null || true)
      if [ -n "$installed" ]; then unselected="$unselected $key"; fi
      ;;
  esac
done
printf 'missing selected installations: %s\n' "${missing# }" | sed 's/: $/: none/'
printf 'installed catalog tools outside selection: %s\n' "${unselected# }" | sed 's/: $/: none/'
if [ -n "$unselected" ]; then
  echo 'Retained shims need a project or local pin after linking; installed versions are kept.'
fi
