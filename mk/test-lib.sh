#!/bin/sh

# Shared lifecycle for tests whose only persistent resource is test_root.
# Callers retain their own shell options, fixtures, and assertions.
test_prepare_path() {
  [ "${DOTFILES_TEST_PATH_READY:-}" != 1 ] || return 0
  test_repo=$(CDPATH='' cd -P -- "${1:-${0%/*}/..}" && pwd -P) || exit 1
  test_original_path=${PATH:-/usr/bin:/bin}
  test_shim_roots=
  for test_dir in "${MISE_SHIMS_DIR:-}" "${MISE_DATA_DIR:-${XDG_DATA_HOME:-${HOME:-}/.local/share}/mise}/shims" "${HOME:-}/.local/share/mise/shims"; do
    [ -n "$test_dir" ] || continue
    test_physical=$(CDPATH='' cd -P -- "$test_dir" 2>/dev/null && pwd -P) || test_physical=$test_dir
    test_shim_roots=${test_shim_roots:+$test_shim_roots:}$test_physical
  done
  test_clean_path=
  while :; do
    test_dir=${test_original_path%%:*}
    test_physical=$(CDPATH='' cd -P -- "${test_dir:-.}" 2>/dev/null && pwd -P) || test_physical=$test_dir
    case :$test_shim_roots: in
      *:"$test_physical":*) ;;
      *) case $test_physical in
        */mise/shims) ;;
        *) test_clean_path=${test_clean_path:+$test_clean_path:}$test_dir ;;
      esac ;;
    esac
    case $test_original_path in *:*) test_original_path=${test_original_path#*:} ;; *) break ;; esac
  done
  # Resolve only standalone test tools, while the real HOME/config still exist.
  # Runtimes use the remaining native PATH; their mise backend environment must
  # not be carried into a scratch HOME. Keep ~/.local/bin and virtualenvs.
  test_mise=${MISE_BIN:-${HOME:-}/.local/bin/mise}
  [ -x "$test_mise" ] || test_mise=$(command -v mise 2>/dev/null || true)
  for test_tool in vim nvim fzf rg jq zsh bash tmux stow shellcheck git make; do
    test_candidate=$(command -v "$test_tool" 2>/dev/null || true)
    [ -n "$test_candidate" ] || continue
    test_dir=${test_candidate%/*}
    test_physical=$(CDPATH='' cd -P -- "$test_dir" 2>/dev/null && pwd -P) || continue
    case :$test_shim_roots: in *:"$test_physical":*) ;; *) continue ;; esac
    [ -n "$test_mise" ] && [ -x "$test_mise" ] || continue
    test_binary=$(MISE_OFFLINE=1 MISE_AUTO_INSTALL=false MISE_EXEC_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false \
      MISE_CEILING_PATHS="$test_repo" MISE_GLOBAL_CONFIG_FILE="$test_repo/setup/tools.toml" \
      "$test_mise" which "$test_tool" </dev/null 2>/dev/null) || continue
    [ -f "$test_binary" ] && [ -x "$test_binary" ] || continue
    test_dir=$(CDPATH='' cd -P -- "${test_binary%/*}" && pwd -P) || continue
    case :$test_shim_roots: in *:"$test_dir":*) continue ;; esac
    test_clean_path=$test_dir${test_clean_path:+:$test_clean_path}
  done
  PATH=${test_clean_path:-/usr/bin:/bin}
  export PATH
  # These exported settings belong to the user's mise session, not fixtures.
  for test_variable in $(env | sed -n -E 's/^((__)?MISE_[A-Za-z0-9_]*)=.*/\1/p'); do
    unset "$test_variable"
  done
  DOTFILES_TEST_PATH_READY=1
  export DOTFILES_TEST_PATH_READY
}

test_init() {
  test_label=$1
  test_root=$(mktemp -d) || exit 1
  # macOS temp paths can be aliases; compare the physical paths tools return.
  test_root=$(CDPATH='' cd -P -- "$test_root" && pwd -P) || exit 1
  trap test_cleanup EXIT
  trap 'exit 1' HUP INT TERM
}

test_cleanup() {
  rm -rf "$test_root"
}

fail() {
  echo "$test_label: $*" >&2
  exit 1
}
