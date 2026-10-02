#!/bin/sh

# shellcheck source=mk/test-lib.sh
. "${0%/*}/test-lib.sh"
test_prepare_path

set -eu

repo=$(CDPATH='' cd -- "${0%/*}/.." && pwd -P)
test_init check-fzf
cd "$repo"

fixture_home=$test_root/home
config=$fixture_home/.config/sheldon/plugins.toml
cache=$fixture_home/.cache/dotfiles/sheldon.zsh
mkdir -p "${config%/*}" "$fixture_home/.config/zsh/plugins" "$test_root/bin"
cp zsh/.config/zsh/plugins/fzf.zsh "$fixture_home/.config/zsh/plugins/fzf.zsh"
cat > "$config" <<'EOF'
shell = "zsh"
[templates]
defer = "zsh-defer source {{ file }}"
[plugins.fzf]
local = "~/.config/zsh/plugins"
use = [ "fzf.zsh" ]
apply = ["defer"]
EOF
cat > "$test_root/bin/sheldon" <<'EOF'
#!/bin/sh
case $1 in
  lock) exit 0 ;;
  source) printf 'zsh-defer source "%s/.config/zsh/plugins/fzf.zsh"\n' "$HOME" ;;
  *) exit 1 ;;
esac
EOF
cat > "$test_root/bin/fzf" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DOTFILES_FZF_LOG"
[ "$1" = --zsh ] || exit 65
case $DOTFILES_FZF_MODE in
  fail) printf 'partial integration\n'; exit 66 ;;
  empty) exit 0 ;;
  syntax) printf 'if then\n'; exit 0 ;;
  delimiter) printf '# valid Zsh\n__DOTFILES_FZF_ZSH__\n'; exit 0 ;;
  fixture) printf 'typeset -g FZF_FIXTURE_LOADED=1\n' ;;
  real) exec "$DOTFILES_REAL_FZF" --zsh ;;
  *) exit 67 ;;
esac
EOF
chmod +x "$test_root/bin/sheldon" "$test_root/bin/fzf"
fzf_log=$test_root/fzf.log

restore() {
  env -i HOME="$fixture_home" PATH="$test_root/bin:/usr/local/bin:/usr/bin:/bin" \
    DOTFILES_FZF_LOG="$fzf_log" DOTFILES_FZF_MODE="$1" \
    DOTFILES_REAL_FZF="${real_fzf:-}" \
    make -s SHELDON_BIN="$test_root/bin/sheldon" FZF_BIN="$test_root/bin/fzf" \
      sheldon-plugins
}

echo "check-fzf: generation is deferred and atomic"
restore fixture >/dev/null
env -i HOME="$fixture_home" PATH="$test_root/bin:/usr/local/bin:/usr/bin:/bin" \
  zsh -f -c '
    zsh-defer() { typeset -ga queued=("$@"); }
    source "$HOME/.cache/dotfiles/sheldon.zsh"
    (( ! ${+FZF_FIXTURE_LOADED} )) || exit 1
    "${queued[@]}"
    [[ $FZF_FIXTURE_LOADED == 1 ]]
  ' || fail "integration did not wait for the deferred wrapper"
[ "$(cat "$fzf_log")" = --zsh ] || fail "startup invoked the fzf binary"

for mode in fail empty syntax delimiter; do
  before=$(cksum < "$cache")
  if restore "$mode" > "$test_root/$mode.out" 2>&1; then
    fail "accepted $mode integration"
  fi
  [ "$(cksum < "$cache")" = "$before" ] || fail "$mode replaced the last good cache"
  for leftover in "$cache".tmp.*; do
    [ ! -e "$leftover" ] || fail "$mode leaked a temporary cache"
  done
done

echo "check-fzf: real bundled widgets, completion, and Atuin precedence"
real_fzf=${DOTFILES_TEST_FZF:-$(sh mk/find-fzf.sh "${HOME}/.local/bin/mise" "$repo/setup/tools.toml" 2>/dev/null || true)}
if [ -n "$real_fzf" ] && "$real_fzf" --zsh >/dev/null 2>&1; then
  restore real >/dev/null
  : > "$fzf_log"
  for atuin in absent present; do
    env -i HOME="$fixture_home" PATH="$test_root/bin:/usr/local/bin:/usr/bin:/bin" \
      TERM=xterm DOTFILES_ATUIN="$atuin" \
      zsh -fi -c '
        zmodload zsh/zle
        autoload -Uz compinit; compinit -d "$HOME/.zcompdump"
        bindkey -v
        if [[ $DOTFILES_ATUIN == present ]]; then
          export FZF_CTRL_R_COMMAND=""
          atuin_search() { :; }; zle -N atuin_search
          bindkey -M viins "^R" atuin_search
        fi
        zsh-defer() { typeset -ga queued=("$@"); }
        alias printf="print -r -- __DOTFILES_ALIAS_SENTINEL__"
        source "$HOME/.cache/dotfiles/sheldon.zsh"
        (( ! $+functions[fzf-file-widget] )) || exit 1
        "${queued[@]}"
        [[ $functions[__fzf_defaults] != *__DOTFILES_ALIAS_SENTINEL__* ]] || exit 8
        [[ $widgets[fzf-file-widget] == user:fzf-file-widget ]] || exit 2
        [[ $widgets[fzf-cd-widget] == user:fzf-cd-widget ]] || exit 3
        [[ $widgets[fzf-completion] == user:fzf-completion ]] || exit 4
        (( $+functions[_fzf_path_completion] )) || exit 5
        if [[ $DOTFILES_ATUIN == present ]]; then
          [[ $(bindkey -M viins "^R") == *atuin_search ]] || exit 6
        else
          [[ $(bindkey -M viins "^R") == *fzf-history-widget ]] || exit 7
        fi
      ' > "$test_root/widgets-$atuin.out" 2>&1 || {
        cat "$test_root/widgets-$atuin.out" >&2
        fail "real bundled integration failed with Atuin $atuin"
      }
  done
  [ ! -s "$fzf_log" ] || fail "real cached startup invoked fzf"
elif [ -n "${CI:-}${DOTFILES_TEST_FZF:-}" ]; then
  fail "required bundled fzf fixture is unavailable: $real_fzf"
else
  echo "check-fzf: bundled fzf unavailable; skipping real integration outside CI"
fi

echo "check-fzf: ok"
