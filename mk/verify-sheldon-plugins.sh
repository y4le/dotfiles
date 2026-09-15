#!/bin/sh

set -efu

fail() {
  echo "sheldon-pins: $*" >&2
  exit 1
}

tmp_dir=$(mktemp -d) || exit 1
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

unset GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

parse_config() {
  config=$1
  output=$2
  [ -f "$config" ] || fail "config not found: $config"

  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function error(message) {
      printf "sheldon-pins: %s:%d: %s\n", FILENAME, NR, message > "/dev/stderr"
      failed = 1
    }
    function scalar(value, key, inner) {
      value = trim(value)
      if (substr(value, 1, 1) != "\"" || substr(value, length(value), 1) != "\"") {
        error(key " must be a double-quoted string")
        return ""
      }
      inner = substr(value, 2, length(value) - 2)
      if (inner ~ /["\\]/) error(key " contains unsupported quoting")
      return inner
    }
    function string_array(value, key, inner, count, item, i, result) {
      value = trim(value)
      if (substr(value, 1, 1) != "[" || substr(value, length(value), 1) != "]") {
        error(key " must be a single-line string array")
        return ""
      }
      inner = trim(substr(value, 2, length(value) - 2))
      if (inner == "") return ""
      count = split(inner, item, ",")
      for (i = 1; i <= count; i++) {
        item[i] = scalar(item[i], key)
        if (item[i] == "") error(key " contains an empty value")
        result = result (i == 1 ? "" : ",") item[i]
      }
      return result
    }
    function finish_plugin(source_count, repo_key) {
      if (plugin == "") return
      source_count = (github != "") + (local_path != "")
      if (source_count != 1) error("plugin " plugin " must have exactly one of github or local")
      if (github != "") {
        if (github !~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/) error("invalid github repo for " plugin)
        if (length(rev) != 40 || rev !~ /^[0-9a-f]+$/) error("plugin " plugin " needs a full lowercase rev")
        repo_key = github
        if ((repo_key in repo_revs) && repo_revs[repo_key] != rev) {
          error("github repo " github " has conflicting revs")
        }
        repo_revs[repo_key] = rev
        if (use != "") {
          use_count = split(use, use_item, ",")
          for (use_index = 1; use_index <= use_count; use_index++) {
            if (use_item[use_index] ~ /^\// || use_item[use_index] ~ /(^|\/)\.\.($|\/)/) {
              error("unsafe use path for " plugin)
            }
          }
        }
        print "github|" plugin "|" github "|" rev "|" rev_note
      } else if (local_path != "") {
        if (rev != "") error("local plugin " plugin " must not have rev")
        if (local_path !~ /^~\/[A-Za-z0-9_.\/-]+$/ || local_path ~ /(^|\/)\.\.($|\/)/) {
          error("unsafe local path for " plugin)
        }
        if (use == "") error("local plugin " plugin " needs use")
        if (use ~ /[*?\[{]/) error("local plugin " plugin " use must be literal")
        print "local|" plugin "|" local_path "||" use
      }
      plugin = github = rev = rev_note = local_path = use = apply = ""
    }
    /^[[:space:]]*($|#)/ { next }
    {
      line = trim($0)
      if (line ~ /^\[plugins\.[a-z0-9-]+\]$/) {
        finish_plugin()
        plugin = line
        sub(/^\[plugins\./, "", plugin)
        sub(/\]$/, "", plugin)
        if (plugin in plugins) error("duplicate plugin section " plugin)
        plugins[plugin] = 1
        section = "plugin"
        next
      }
      if (line ~ /^\[plugins\./) {
        error("unsupported plugin section")
        section = "invalid"
        next
      }
      if (line == "[templates]") {
        finish_plugin()
        section = "templates"
        next
      }
      if (line ~ /^\[/) {
        finish_plugin()
        error("unsupported section " line)
        section = "invalid"
        next
      }
      if (section == "templates") {
        if (line !~ /^[A-Za-z0-9_-]+[[:space:]]*=[[:space:]]*".*"$/) {
          error("templates must use single-line double-quoted values")
        }
        next
      }
      if (section != "plugin") {
        if (line != "shell = \"zsh\"") error("unsupported top-level setting")
        next
      }

      equals = index(line, "=")
      if (!equals) {
        error("expected key = value in plugin " plugin)
        next
      }
      key = trim(substr(line, 1, equals - 1))
      value = trim(substr(line, equals + 1))
      if (key !~ /^(github|rev|local|use|apply)$/) {
        error("unsupported key " key " in plugin " plugin)
        next
      }
      key_id = plugin SUBSEP key
      if (key_id in keys) error("duplicate key " key " in plugin " plugin)
      keys[key_id] = 1

      if (key == "rev") {
        hash = index(value, "#")
        if (hash) {
          rev_note = trim(substr(value, hash + 1))
          value = trim(substr(value, 1, hash - 1))
        }
        rev = scalar(value, key)
      } else {
        if (index(value, "#")) error("trailing comments are only allowed on rev")
        if (key == "github") github = scalar(value, key)
        else if (key == "local") local_path = scalar(value, key)
        else if (key == "use") use = string_array(value, key)
        else if (key == "apply") apply = string_array(value, key)
      }
    }
    END {
      finish_plugin()
      exit failed
    }
  ' "$config" > "$output" || exit 1
}

lint_config() {
  config=$1
  mise_config=$2
  records=$tmp_dir/records
  parse_config "$config" "$records"

  fzf_version=$(awk -F '"' '/^[[:space:]]*"aqua:junegunn\/fzf"[[:space:]]*=/ { print $4 }' \
    "$mise_config")
  [ -n "$fzf_version" ] || fail "mise fzf version is missing"
  fzf_count=0

  while IFS='|' read -r kind name source rev note; do
    if [ "$kind" = local ]; then
      relative=${source#\~/}
      old_ifs=$IFS
      IFS=,
      # The parser emits a comma-delimited use list; split it deliberately.
      # shellcheck disable=SC2086
      set -- $note
      IFS=$old_ifs
      for used in "$@"; do
        suffix=/$relative/$used
        if ! git -c core.quotePath=false ls-files | \
          awk -v suffix="$suffix" 'substr($0, length($0) - length(suffix) + 1) == suffix { found = 1 } END { exit !found }'; then
          fail "local plugin $name does not map to a tracked file: $source/$used"
        fi
      done
    elif [ "$source" = junegunn/fzf ]; then
      fzf_count=$((fzf_count + 1))
      [ "$note" = "v$fzf_version" ] || \
        fail "fzf rev comment must be # v$fzf_version"
    fi
  done < "$records"

  [ "$fzf_count" -eq 1 ] || fail "expected one junegunn/fzf plugin"
  echo "check-pins: Sheldon plugin config ok"
}

git_in_checkout() {
  checkout=$1
  shift
  GIT_DIR="$checkout/.git" GIT_WORK_TREE="$checkout" \
    git --no-optional-locks --no-replace-objects -c core.fsmonitor=false \
      -c core.checkStat=default -c core.trustctime=true "$@"
}

verification_failure() {
  name=$1
  directory=$2
  message=$3
  echo "sheldon-pins: plugin $name: $message" >&2
  echo "sheldon-pins: checkout: $directory" >&2
  echo "sheldon-pins: review/remove that checkout or run:" >&2
  echo "sheldon-pins: SHELDON_DATA_DIR='$data_dir' ~/.local/bin/sheldon lock --reinstall" >&2
  exit 1
}

verify_checkouts() {
  config=$1
  data_dir=$2
  cache=$3
  records=$tmp_dir/records
  allowed=$tmp_dir/allowed
  paths=$tmp_dir/cache-paths
  : > "$allowed"
  parse_config "$config" "$records"
  [ -f "$cache" ] || fail "cache not found: $cache"

  while IFS='|' read -r kind name source rev note; do
    [ "$kind" = github ] || continue
    directory=$data_dir/repos/github.com/$source
    printf '%s\n' "$directory" >> "$allowed"
    if [ ! -d "$directory" ] || [ -L "$directory" ] || \
      [ ! -d "$directory/.git" ] || [ -L "$directory/.git" ]; then
      verification_failure "$name" "$directory" "checkout is missing, linked, or not an independent Git repository"
    fi
    actual=$(git_in_checkout "$directory" rev-parse --verify 'HEAD^{commit}' 2>/dev/null) || \
      verification_failure "$name" "$directory" "could not read HEAD"
    [ "$actual" = "$rev" ] || \
      verification_failure "$name" "$directory" "expected $rev, got $actual"
    dirty=$(git_in_checkout "$directory" status --porcelain --untracked-files=all --ignored 2>/dev/null) || \
      verification_failure "$name" "$directory" "could not inspect checkout"
    if [ -n "$dirty" ]; then
      echo "$dirty" | sed -n '1,10p' >&2
      verification_failure "$name" "$directory" "checkout has local, untracked, or ignored changes"
    fi
    flags_file=$tmp_dir/index-flags-$name
    git_in_checkout "$directory" ls-files -v > "$flags_file" 2>/dev/null || \
      verification_failure "$name" "$directory" "could not inspect index flags"
    hidden=$(awk 'substr($0, 1, 1) == "S" || substr($0, 1, 1) ~ /^[a-z]$/ { print }' \
      "$flags_file")
    if [ -n "$hidden" ]; then
      echo "$hidden" | sed -n '1,10p' >&2
      verification_failure "$name" "$directory" "index flags can hide checkout changes"
    fi
    grep -F "\"$directory/" "$cache" >/dev/null || \
      verification_failure "$name" "$directory" "rendered cache does not source this checkout"
  done < "$records"

  awk -v prefix="\"$data_dir/repos/github.com/" '
    {
      rest = $0
      while ((start = index(rest, prefix)) > 0) {
        rest = substr(rest, start + 1)
        finish = index(rest, "\"")
        if (!finish) break
        print substr(rest, 1, finish - 1)
        rest = substr(rest, finish + 1)
      }
    }
  ' "$cache" > "$paths"

  while IFS= read -r sourced_path; do
    known=0
    while IFS= read -r directory; do
      case $sourced_path in "$directory"/*) known=1; break ;; esac
    done < "$allowed"
    [ "$known" -eq 1 ] || fail "rendered cache sources an unpinned checkout: $sourced_path"
  done < "$paths"
}

command=${1:-}
case $command in
  lint)
    shift
    [ "$#" -eq 2 ] || fail "lint requires CONFIG and MISE_CONFIG"
    lint_config "$1" "$2"
    ;;
  verify)
    shift
    [ "$#" -eq 3 ] || fail "verify requires CONFIG, DATA_DIR, and CACHE"
    verify_checkouts "$1" "$2" "$3"
    ;;
  *) fail "usage: $0 {lint CONFIG MISE_CONFIG|verify CONFIG DATA_DIR CACHE}" ;;
esac
