#!/bin/sh
set -eu
set -f

# Curated agents used by this setup. Paths and write targets match Herdr v0.9.1
# src/integration/{env,targets}.rs; review these when updating the Herdr pin.
mode=$1
repo=$2
agent_paths() {
  case $1 in
    claude) command_name=claude; config_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}; files='settings.json'; hook_dir=hooks ;;
    codex) command_name=codex; config_dir=${CODEX_HOME:-$HOME/.codex}; files='hooks.json config.toml'; hook_dir=. ;;
    antigravity-cli) command_name=agy; config_dir=${ANTIGRAVITY_CLI_CONFIG_DIR:-$HOME/.gemini/config}; files='hooks.json'; hook_dir=hooks ;;
    *) echo "unsupported setup integration: $1; choose claude, codex, antigravity-cli, or use 'herdr integration install NAME' directly" >&2; return 1 ;;
  esac
  # Match a literal tilde in an environment override, then expand it ourselves.
  # shellcheck disable=SC2088
  case $config_dir in
    '~') config_dir=$HOME ;;
    '~/'*) config_dir=$HOME/${config_dir#\~/} ;;
  esac
}

check_writable() {
  path=$1
  if [ -e "$path" ]; then
    [ -w "$path" ] || { echo "Herdr integration destination is not writable: $path" >&2; return 1; }
  elif [ -L "$path" ]; then
    echo "Herdr integration destination is a dangling link: $path" >&2; return 1
  else
    parent=${path%/*}
    [ -d "$parent" ] && [ -w "$parent" ] || { echo "Herdr integration parent is not writable: $parent" >&2; return 1; }
  fi
}

check_config_file() {
  config_path=$1
  resolved=$config_path
  depth=0
  while [ -L "$resolved" ]; do
    depth=$((depth + 1))
    [ "$depth" -le 40 ] || { echo "Herdr config has too many symbolic links: $config_path" >&2; return 1; }
    target=$(readlink "$resolved") || return 1
    case $target in /*) resolved=$target ;; *) resolved=${resolved%/*}/$target ;; esac
  done
  [ ! -e "$resolved" ] || [ -f "$resolved" ] || {
    echo "Herdr integration config is not a regular file: $config_path" >&2; return 1
  }
  check_writable "$config_path" || return 1
  # Config replacement creates a temporary file alongside the resolved target.
  # This matters when the agent directory contains links into another checkout.
  check_writable "${resolved%/*}" || return 1
  if [ -f "$resolved" ] && [ -n "$(find "$resolved" -links +1 -print)" ]; then
    echo "Herdr integration config has multiple hard links: $config_path" >&2; return 1
  fi
}

check_agent() {
  agent_paths "$1" || return 1
  sh "$repo/scripts/.local/bin/dotfiles-tool" "$command_name" >/dev/null || {
    echo "Herdr integration $1 needs $command_name available on PATH" >&2; return 1
  }
  [ -d "$config_dir" ] || { echo "Herdr integration $1 needs $config_dir; initialize the agent first" >&2; return 1; }
  check_writable "$config_dir" || return 1
  for file in $files; do
    check_config_file "$config_dir/$file" || return 1
  done
  path=$config_dir/$hook_dir
  [ ! -e "$path" ] || [ -d "$path" ] || { echo "Herdr hooks path is not a directory: $path" >&2; return 1; }
  check_writable "$path" || return 1
  if [ -d "$path" ]; then
    path=$path/herdr-agent-state.sh
    [ ! -e "$path" ] || [ -f "$path" ] || { echo "Herdr hook is not a regular file: $path" >&2; return 1; }
    check_writable "$path" || return 1
  fi
}

case $mode in
  --select)
    selection=$3
    [ -n "$selection" ] || { echo 'HERDR_INTEGRATIONS must name at least one integration' >&2; exit 1; }
    if [ "$selection" = auto ]; then
      selected=
      for agent in claude codex antigravity-cli; do
        agent_paths "$agent"
        if ! sh "$repo/scripts/.local/bin/dotfiles-tool" "$command_name" >/dev/null || [ ! -d "$config_dir" ]; then
          echo "skipping Herdr integration: $agent (needs $command_name on PATH and initialized $config_dir)" >&2
          continue
        fi
        check_agent "$agent" || exit 1
        selected=${selected:+$selected }$agent
      done
      [ -n "$selected" ] || echo 'no initialized agents detected; start a configured shell and initialize an agent, then rerun' >&2
    else
      selected=$selection
      set -- $selected
      [ "$#" -gt 0 ] || { echo 'HERDR_INTEGRATIONS must name at least one integration' >&2; exit 1; }
      # Intentional word splitting of a validated space-separated selection.
      for agent in $selected; do check_agent "$agent" || exit 1; done
    fi
    printf '%s\n' "$selected"
    ;;
  --install)
    herdr_bin=$3
    selected=$4
    umask 077
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    trap 'exit 1' HUP INT TERM
    # Exercise Herdr's own config parsing and edits on private copies before
    # modifying ANY real agent. Never publish staged hooks (they embed paths).
    for agent in $selected; do
      check_agent "$agent" || exit 1
      mkdir -p "$stage/$agent"
      for file in $files; do
        [ ! -f "$config_dir/$file" ] || cp "$config_dir/$file" "$stage/$agent/$file"
      done
      HOME="$stage" CLAUDE_CONFIG_DIR="$stage/$agent" CODEX_HOME="$stage/$agent" \
        ANTIGRAVITY_CLI_CONFIG_DIR="$stage/$agent" \
        "$herdr_bin" integration install "$agent" >/dev/null
    done
    # Preflight is not a transaction: later I/O failures may require a rerun.
    for agent in $selected; do
      echo "installing Herdr integration: $agent"
      "$herdr_bin" integration install "$agent"
    done
    ;;
  *) echo "usage: $0 --select REPO SELECTION | --install REPO HERDR_BIN SELECTION" >&2; exit 2 ;;
esac
