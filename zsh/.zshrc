# this file should be symlinked to ~/.zshrc
# ~/.zshrc is only sourced for interactive shells
# use ~/.zshenv if you always want to source

# source machine-local setup before interactive tools
if [[ -f $HOME/.config/zsh/hooks/pre.zsh ]]; then
  source $HOME/.config/zsh/hooks/pre.zsh
elif [[ -f $HOME/.pre_profile ]]; then
  source $HOME/.pre_profile
fi

if (( $+commands[bat] )); then
  export MANPAGER='bat -plman'
  export MANROFFOPT=-c
else
  export MANPAGER=$PAGER
fi
# mise shims are on PATH in .zshenv for all shell types.

# Atuin creates a regular config file when an old shell hook runs after its
# package is unlinked. Only config linked into the Atuin package selects it.
atuin_config=$HOME/.config/atuin/config.toml
atuin_managed=0
if [[ -f $atuin_config && ${atuin_config:A} != ${atuin_config:a} &&
  ${atuin_config:A} == */atuin/.config/atuin/config.toml ]]; then
  atuin_managed=1
fi
unset atuin_config

# fzf is loaded asynchronously; keep it from taking ctrl-R back from atuin
if (( atuin_managed )) && command -v atuin &>/dev/null; then
  export FZF_CTRL_R_COMMAND=""
fi

# SHELDON — source only the explicitly restored cache; startup stays offline
sheldon_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/sheldon.zsh"
if [[ -r "$sheldon_cache" ]]; then
  source "$sheldon_cache"
else
  [[ -r $HOME/.config/zsh/themes/minimal.zsh-theme ]] && \
    source $HOME/.config/zsh/themes/minimal.zsh-theme
  [[ -o interactive ]] && \
    print -u2 "dotfiles: zsh plugins not restored; run 'make plugins'"
fi

# Initialize completion before interactive tools and local sources use compdef.
zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
if [[ -d "$zsh_cache_dir" ]] || command mkdir -p -m 700 "$zsh_cache_dir"; then
  autoload -Uz compinit
  compinit -i -d "$zsh_cache_dir/zcompdump-$ZSH_VERSION"
else
  print -u2 "dotfiles: could not create $zsh_cache_dir; completion disabled"
fi
unset zsh_cache_dir

# zoxide — frecency-based directory navigation
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# source all files in these dirs
source_dirs=(
  ~/.config/shell/functions
  ~/.config/zsh/sources
)

for source_dir in $source_dirs; do
  if [[ -d "$source_dir" ]]; then
    for src in $source_dir/**/*(N-.); do
      source $src
    done
  fi
done


# TERMINAL OPTIONS

bindkey -v # vim mode
KEYTIMEOUT=1 # vim mode timeout 1ms instead of .4s

export CLICOLOR=1 # ANSI colors in iterm2

SAVEHIST=100000        # keep history longer
HISTSIZE=100000        # ditto
zsh_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
if [[ ! -d "$zsh_state_dir" ]] && ! command mkdir -p -m 700 "$zsh_state_dir"; then
  print -u2 "dotfiles: could not create $zsh_state_dir; using ~/.history"
  HISTFILE="$HOME/.history"
else
  HISTFILE="$zsh_state_dir/history"
fi
typeset +x HISTFILE HISTSIZE SAVEHIST KEYTIMEOUT
unset zsh_state_dir
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt inc_append_history     # add commands to HISTFILE in order of execution
setopt share_history          # share history data


# SHORTCUTS

# ctrl-g Yazi navigator: keep directory changes in the current shell.
function yazinav() {
  emulate -L zsh
  zle -I
  local yazi_rc
  y < "$TTY"
  yazi_rc=$?
  zle reset-prompt
  zle redisplay
  return "$yazi_rc"
}
zle -N yazinav
bindkey '^g' yazinav

# ctrl-R history search
if (( atuin_managed )) && command -v atuin &>/dev/null; then
  export ATUIN_NOBIND="true"
  eval "$(atuin init zsh --disable-up-arrow --disable-ai)"

  if [[ -n "$TMUX" ]]; then
    export ATUIN_TMUX_POPUP="true"
  else
    export ATUIN_TMUX_POPUP="false"
  fi

  bindkey -M emacs '^r' atuin-search
  bindkey -M viins '^r' atuin-search-viins
  bindkey -M vicmd '^r' atuin-search-vicmd

  # ctrl-X o: successful commands only (Atuin's TUI cannot filter by exit status)
  function atuin-success-history() {
    if ! command -v fzf &>/dev/null; then
      zle -M "fzf not found"
      return 1
    fi

    zle -I
    local -a selector=(fzf)
    if [[ "$ATUIN_TMUX_POPUP" == "true" ]] && \
      command -v fzf-tmux &>/dev/null && \
      tmux list-commands 2>/dev/null | command grep -q '^display-popup '; then
      selector=(
        fzf-tmux
        -p "${ATUIN_TMUX_POPUP_WIDTH:-90%},${ATUIN_TMUX_POPUP_HEIGHT:-70%}"
      )
    fi

    local selected
    selected=$(
      ATUIN_LOG=error atuin search --exit 0 --cmd-only --print0 --limit 10000 |
        "${selector[@]}" --read0 --scheme=history --query "$BUFFER" --prompt='success> '
    )
    local selection_rc=$?
    zle reset-prompt

    if (( selection_rc == 0 )) && [[ -n "$selected" ]]; then
      BUFFER="$selected"
      CURSOR=${#BUFFER}
    fi
  }
  zle -N atuin-success-history
  bindkey -M emacs '^Xo' atuin-success-history
  bindkey -M viins '^Xo' atuin-success-history
  bindkey -M vicmd '^Xo' atuin-success-history
fi
unset atuin_managed

# ctrl-X ctrl-e edit current command in vim
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# fzf: fuzzy finder
export FZF_DEFAULT_OPTS="--bind 'ctrl-y:execute-silent(printf %s {} | cpy)'"
export fzf_preview_opt="--preview-window down:50% --preview '(bat --color=always --line-range :200 {} || cat {} || tree -C {}) 2>/dev/null'"
export FZF_CTRL_T_OPTS="--bind 'ctrl-l:execute(bat --color=always {} | less -Rf || less -f {}),ctrl-f:execute(bat --paging=always {} || less -f {})' $fzf_preview_opt"

unset FZF_TMUX
export FZF_TMUX_HEIGHT=80%

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules,.venv}/*"'
if type filez &>/dev/null; then
  export FZF_DEFAULT_COMMAND='filez'
  export FZF_CTRL_T_COMMAND='filez --print0'
  export FZF_CTRL_T_OPTS="--read0 $FZF_CTRL_T_OPTS"
else
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# source final machine-local overrides
if [[ -f $HOME/.config/zsh/hooks/post.zsh ]]; then
  source $HOME/.config/zsh/hooks/post.zsh
elif [[ -f $HOME/.post_profile ]]; then
  source $HOME/.post_profile
fi
