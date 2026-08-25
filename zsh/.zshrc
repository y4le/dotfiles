# this file should be symlinked to ~/.zshrc
# ~/.zshrc is only sourced for interactive shells
# use ~/.zshenv if you always want to source

# source ~/.pre_profile if present
[[ -f $HOME/.pre_profile ]] && source $HOME/.pre_profile

# mise — pinned runtimes and cross-platform CLI tools
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# fzf is loaded asynchronously; keep it from taking ctrl-R back from atuin
if command -v atuin &>/dev/null; then
  export FZF_CTRL_R_COMMAND=""
fi

# SHELDON — zsh plugin manager
if ! command -v sheldon &>/dev/null; then
  echo "sheldon not found — run 'make setup' from your dotfiles repo"
  return
fi
eval "$(sheldon source)"

# zoxide — frecency-based directory navigation
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# source all files in these dirs
source_dirs=(
  ~/.funcs
  ~/.config/zsh/sources
)

for source_dir in $source_dirs; do
  if [[ -d "$source_dir" ]]; then
    for src in $source_dir/**/*(N); do
      source $src
    done
  fi
done


# TERMINAL OPTIONS

bindkey -v # vim mode
export KEYTIMEOUT=1 # vim mode timeout 1ms instead of .4s

export CLICOLOR=1 # ANSI colors in iterm2

export SAVEHIST=100000        # keep history longer
export HISTSIZE=100000        # ditto
export HISTFILE=~/.history    # potentially share history with other shells
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt inc_append_history     # add commands to HISTFILE in order of execution
setopt share_history          # share history data


# SHORTCUTS

# quick re-source this file
alias src="source ~/.zshrc"

# ctrl-g yazi: file system navigator
function yazinav() {
  zle -I
  y < $TTY
  zle reset-prompt; zle redisplay
}
zle -N yazinav
bindkey '^g' yazinav

# ctrl-R history search (atuin with fzf fallback)
if command -v atuin &>/dev/null; then
  export ATUIN_NOBIND="true"
  eval "$(atuin init zsh --disable-up-arrow --disable-ai)"

  # use a popup only when this tmux server provides display-popup
  if [[ -n "$TMUX" ]] && tmux list-commands 2>/dev/null | command grep -q '^display-popup '; then
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
    if [[ "$ATUIN_TMUX_POPUP" == "true" ]] && command -v fzf-tmux &>/dev/null; then
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
    local status=$?
    zle reset-prompt

    if (( status == 0 )) && [[ -n "$selected" ]]; then
      BUFFER="$selected"
      CURSOR=${#BUFFER}
    fi
  }
  zle -N atuin-success-history
  bindkey -M emacs '^Xo' atuin-success-history
  bindkey -M viins '^Xo' atuin-success-history
  bindkey -M vicmd '^Xo' atuin-success-history
else
  bindkey -M viins '^r' fzf-insert-history
  bindkey -M vicmd '^r' fzf-insert-history
fi

# ctrl-X ctrl-e edit current command in vim
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# fzf: fuzzy finder
fzf_action_list=()
for k v (
  "ctrl-l" "execute(bat --color=always {} | less -Rf || less -f {})" # quick preview file
  "ctrl-f" "execute(bat --paging=always {} || less -f {})" # full pager file
  "ctrl-y" "execute-silent(echo -n {} | cpy)" # copy selected line to clipboard
); do
  fzf_action_list+=("$k:$v")
done
export FZF_DEFAULT_OPTS="--bind '${(j.,.)fzf_action_list}'"
export fzf_preview_opt="--preview-window down:50% --preview '(bat {} || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_T_OPTS="$fzf_preview_opt"

export FZF_TMUX=1
export FZF_TMUX_HEIGHT=80

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules,.venv}/*"'
type filez &>/dev/null && export FZF_DEFAULT_COMMAND='filez'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# source machine specific env/aliases
[[ -f $HOME/.post_profile ]] && source $HOME/.post_profile
