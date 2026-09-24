#!/bin/sh

set -efu

pins_file=${DOTFILES_PINS_FILE:-setup/pins/downloads.txt}
tmp_dir=

fail() {
  echo "pinned: $*" >&2
  exit 1
}

cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}

trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

platform() {
  if [ -n "${DOTFILES_PLATFORM:-}" ]; then
    case $DOTFILES_PLATFORM in
      linux-amd64 | linux-arm64 | darwin-amd64 | darwin-arm64)
        printf '%s\n' "$DOTFILES_PLATFORM"
        return
        ;;
      *) fail "invalid DOTFILES_PLATFORM: $DOTFILES_PLATFORM" ;;
    esac
  fi

  case $(uname -s) in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) fail "unsupported operating system: $(uname -s)" ;;
  esac

  machine=$(uname -m)
  case $machine in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) fail "unsupported architecture: $machine" ;;
  esac

  if [ "$os" = darwin ] && [ "$arch" = amd64 ]; then
    translated=$(sysctl -n sysctl.proc_translated 2>/dev/null || true)
    if [ "$translated" = 1 ]; then
      arch=arm64
    fi
  fi

  printf '%s-%s\n' "$os" "$arch"
}

sha256() {
  [ "$#" -eq 1 ] || fail "sha256 requires one file"
  [ -f "$1" ] || fail "cannot hash missing file: $1"

  tool=${DOTFILES_SHA256_TOOL:-}
  if [ -z "$tool" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      tool=sha256sum
    elif command -v shasum >/dev/null 2>&1; then
      tool=shasum
    elif command -v openssl >/dev/null 2>&1; then
      tool=openssl
    else
      fail "need sha256sum, shasum, or openssl"
    fi
  fi

  case $tool in
    sha256sum)
      command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not found"
      output=$(sha256sum < "$1") || fail "sha256sum failed: $1"
      ;;
    shasum)
      command -v shasum >/dev/null 2>&1 || fail "shasum not found"
      output=$(shasum -a 256 < "$1") || fail "shasum failed: $1"
      ;;
    openssl)
      command -v openssl >/dev/null 2>&1 || fail "openssl not found"
      output=$(openssl dgst -sha256 -r < "$1") || fail "openssl failed: $1"
      ;;
    *) fail "unsupported SHA-256 tool: $tool" ;;
  esac

  set -- $output
  hash=$(printf '%s' "${1:-}" | tr 'A-F' 'a-f')
  case $hash in
    *[!0-9a-f]* | '') fail "$tool returned an invalid SHA-256" ;;
  esac
  [ "${#hash}" -eq 64 ] || fail "$tool returned an invalid SHA-256"
  printf '%s\n' "$hash"
}

lint() {
  [ -f "$pins_file" ] || fail "pins file not found: $pins_file"

  awk '
    function bad(message) {
      printf "pinned: %s:%d: %s\n", FILENAME, NR, message > "/dev/stderr"
      failed = 1
    }
    /^[[:space:]]*(#|$)/ { next }
    {
      if (NF != 5 && NF != 7) bad("expected 5 or 7 fields")
      if ($1 !~ /^[a-z0-9-]+$/) bad("invalid name")
      if ($2 !~ /^[A-Za-z0-9._+-]+$/) bad("invalid version")
      if ($3 !~ /^(linux-amd64|linux-arm64|darwin-amd64|darwin-arm64|any)$/) bad("invalid platform")
      if (length($4) != 64 || $4 !~ /^[0-9a-f]+$/) bad("invalid download SHA-256")
      if (NF == 7 && (length($7) != 64 || $7 !~ /^[0-9a-f]+$/)) bad("invalid installed SHA-256")
      if (NF == 7 && ($6 ~ /^\// || $6 ~ /(^|\/)\.\.($|\/)/)) bad("unsafe archive member")
      pair = $1 SUBSEP $3
      if (pair in pairs) bad("duplicate name and platform")
      pairs[pair] = 1
      if (($1 in versions) && versions[$1] != $2) bad("mixed versions for one name")
      versions[$1] = $2
      if ($3 == "any") any[$1] = 1
      else specific[$1] = 1
      seen[$1 SUBSEP $3] = 1
      urls[NR] = $5
      url_versions[NR] = $2
    }
    END {
      for (name in any) if (name in specific) bad("any cannot be mixed with specific platforms for " name)
      need[++n] = "actionlint linux-amd64"
      need[++n] = "herdr linux-amd64"
      need[++n] = "herdr linux-arm64"
      need[++n] = "herdr darwin-amd64"
      need[++n] = "herdr darwin-arm64"
      need[++n] = "mise linux-amd64"
      need[++n] = "mise linux-arm64"
      need[++n] = "mise darwin-amd64"
      need[++n] = "mise darwin-arm64"
      need[++n] = "sheldon linux-amd64"
      need[++n] = "sheldon linux-arm64"
      need[++n] = "sheldon darwin-arm64"
      need[++n] = "vim-plug any"
      for (i = 1; i <= n; i++) {
        split(need[i], required, " ")
        if (!((required[1] SUBSEP required[2]) in seen)) {
          bad("missing " required[1] " pin for " required[2])
        }
      }
      exit failed
    }
  ' "$pins_file" || exit 1

  while IFS= read -r line || [ -n "$line" ]; do
    set -- $line
    [ "$#" -gt 0 ] || continue
    case $1 in '#'* ) continue ;; esac
    version=$2
    url=$5
    case $url in
      https://github.com/* | https://raw.githubusercontent.com/* | https://static.crates.io/*) ;;
      *) fail "unapproved or non-HTTPS URL: $url" ;;
    esac
    case $url in
      */HEAD/* | */master/* | */main/* | */latest/*) fail "mutable URL: $url" ;;
    esac
    case $url in
      https://github.com/*)
        case $url in
          */releases/download/*"$version"/*) ;;
          *) fail "GitHub release URL does not contain version $version: $url" ;;
        esac
        ;;
      https://raw.githubusercontent.com/*)
        printf '%s\n' "$url" | grep -Eq '/[0-9a-f]{40}/' || \
          fail "raw GitHub URL is not commit-pinned: $url"
        ;;
    esac
  done < "$pins_file"

  echo "check-pins: pin file ok"
}

select_pin() {
  [ "$#" -eq 1 ] || fail "pin selection requires one name"
  selected_platform=$(platform)
  matches=$(awk -v name="$1" -v platform="$selected_platform" '
    /^[[:space:]]*(#|$)/ { next }
    $1 == name && ($3 == platform || $3 == "any") { print }
  ' "$pins_file")
  count=$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')
  if [ "$count" -eq 0 ]; then
    fail "no reviewed $1 pin for $selected_platform; see setup/pins/README.md"
  fi
  [ "$count" -eq 1 ] || fail "expected one pinned $1 for $selected_platform, found $count"
  printf '%s\n' "$matches"
}

read_pin() {
  pin=$(select_pin "$1")
  set -- $pin
  pin_name=$1
  pin_version=$2
  pin_download_sha=$4
  pin_url=$5
  pin_member=${6:-}
  pin_installed_sha=${7:-$4}
}

matches_installed_pin() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  actual=$(sha256 "$1") || return 1
  [ "$actual" = "$pin_installed_sha" ]
}

download_pin() {
  output=$1
  command -v curl >/dev/null 2>&1 || fail "curl not found"
  curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 \
    --connect-timeout 30 --max-time 600 -o "$output" "$pin_url" </dev/null || \
    fail "download failed: $pin_url"
  actual=$(sha256 "$output")
  if [ "$actual" != "$pin_download_sha" ]; then
    echo "pinned: checksum mismatch: $pin_url" >&2
    echo "pinned: expected $pin_download_sha" >&2
    echo "pinned: actual   $actual" >&2
    exit 1
  fi
}

status() {
  [ "$#" -eq 2 ] || fail "status requires a name and destination"
  read_pin "$1"
  if matches_installed_pin "$2"; then
    echo "$pin_name $pin_version is pinned at $2"
    return 0
  fi
  echo "$pin_name $pin_version is missing or drifted at $2" >&2
  return 1
}

install() {
  [ "$#" -eq 3 ] || fail "install requires a name, destination, and mode"
  read_pin "$1"
  destination=$2
  mode=$3

  if matches_installed_pin "$destination"; then
    chmod "$mode" "$destination"
    echo "$pin_name $pin_version already pinned at $destination"
    return 0
  fi

  if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
    fail "refusing non-regular destination: $destination"
  fi
  if [ -f "$destination" ]; then
    previous=$(sha256 "$destination")
    echo "replacing $destination (sha256 $previous) with pinned $pin_name $pin_version"
  fi

  destination_dir=$(dirname "$destination")
  mkdir -p "$destination_dir"
  tmp_dir=$(mktemp -d "$destination_dir/.pinned.XXXXXX") || fail "could not create temporary directory"
  download_pin "$tmp_dir/download"

  payload=$tmp_dir/download
  if [ -n "$pin_member" ]; then
    mkdir "$tmp_dir/extracted"
    tar --no-same-owner -xzf "$tmp_dir/download" -C "$tmp_dir/extracted" "$pin_member" || \
      fail "could not extract $pin_member from $pin_url"
    payload=$tmp_dir/extracted/$pin_member
    [ -f "$payload" ] && [ ! -L "$payload" ] || fail "archive member is not a regular file: $pin_member"
    actual=$(sha256 "$payload")
    [ "$actual" = "$pin_installed_sha" ] || \
      fail "installed checksum mismatch for $pin_name: expected $pin_installed_sha, got $actual"
  fi

  chmod "$mode" "$payload"
  case $mode in
    *1* | *3* | *5* | *7*)
      mkdir "$tmp_dir/probe-home"
      version_output=$(HOME="$tmp_dir/probe-home" XDG_CACHE_HOME="$tmp_dir/probe-home/cache" \
        XDG_CONFIG_HOME="$tmp_dir/probe-home/config" XDG_DATA_HOME="$tmp_dir/probe-home/data" \
        MISE_HIDE_UPDATE_WARNING=1 MISE_OFFLINE=1 \
        "$payload" --version </dev/null 2>&1) || fail "$pin_name binary did not run"
      printf '%s\n' "$version_output" | grep -F "$pin_version" >/dev/null || \
        fail "$pin_name binary did not report version $pin_version"
      ;;
  esac

  mv -f "$payload" "$destination"
  cleanup
  tmp_dir=
  echo "installed $pin_name $pin_version at $destination"
}

command=${1:-}
case $command in
  platform)
    shift
    [ "$#" -eq 0 ] || fail "platform takes no arguments"
    platform
    ;;
  sha256)
    shift
    sha256 "$@"
    ;;
  lint)
    shift
    [ "$#" -eq 0 ] || fail "lint takes no arguments"
    lint
    ;;
  status)
    shift
    status "$@"
    ;;
  install)
    shift
    install "$@"
    ;;
  *) fail "usage: $0 {platform|sha256 FILE|lint|status NAME DEST|install NAME DEST MODE}" ;;
esac
