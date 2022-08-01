# this file should be symlinked to ~/.zshrc
# ~/.zshrc is only sourced for interactive shells
# use ~/.zshenv if you always want to source

# source ~/.pre_profile if present
[[ -f $HOME/.pre_profile ]] && source $HOME/.pre_profile

# ZPLUG

# install zplug if missing
[[ -d ~/.zplug ]] || git clone https://github.com/b4b4r07/zplug ~/.zplug

# set home
export ZPLUG_HOME=~/.zplug
source $ZPLUG_HOME/init.zsh

zplug clear # clear old packages
zplug zplug/zplug, hook-build:"zplug --self-manage" # self manage

zplug "~/.config/zsh/themes/", use:"minimal.zsh-theme", from:local, as:theme

# helpers for the `use:` tag for zplug commands
a6='amd64' && x8='x86_64' && tz='.tar.gz'
os='darwin' && [[ $OSTYPE == *linux* ]] && os='linux'

# commands
zplug "clvv/fasd", as:command, use:fasd
zplug "facebook/PathPicker", as:command, use:fpp
zplug "junegunn/fzf", use:"shell/*.zsh", defer:2
zplug "junegunn/fzf-bin", from:gh-r, as:command, rename-to:fzf
zplug "knqyf263/pet", from:gh-r, as:command, rename-to:pet, use:"*$os*$a6*$tz"
zplug "ranger/ranger", as:command, rename-to:ranger, use:ranger.py
zplug "raylee/tldr", as:command, use:tldr
zplug "sharkdp/bat", from:gh-r, as:command, rename-to:bat, use:"*$x8*$os*$tz"
zplug "sharkdp/fd", from:gh-r, as:command, rename-to:fd
zplug "zdharma-continuum/zsh-diff-so-fancy", as:command, use:bin/git-dsf
zplug "rkitover/vimpager", as:command
zplug "fdw/rofimoji", as:command, rename-to:rofimoji, use:rofimoji.py
zplug "wustho/epr", as:command, rename-to:epr, use:epr.py

# plugins
zplug "b4b4r07/zsh-vimode-visual", defer:3        # add visual vim mode to the cli
zplug "plugins/fasd", from:oh-my-zsh, if:"(( $+commands[fasd] ))", on:"clvv/fasd"
zplug "wfxr/forgit", defer:1                      # fzf + git: ga(dd) glo(g) gi(gnore) gd(iff) gcf(ile)
zplug "ytet5uy4/fzf-widgets"                      # fzf widgets - used to get fzf-insert-history
zplug "zdharma/fast-syntax-highlighting", defer:2 # fast cli syntax highlighting
zplug "zlsun/solarized-man"                       # colorful man pages
zplug "zsh-users/zsh-autosuggestions"             # typeahead command suggestions from history

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

# if necessary, install plugins
if ! zplug check --verbose; then
  printf "Install zplug plugins? [y/N]: "
  if read -q; then
    echo; zplug install
  fi
fi

# load plugins into PATH
zplug load


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

# ctrl-g ranger: file system navigator
function rangernav() {
  source ranger < $TTY # source so when we move we cd
  zle reset-prompt; zle redisplay
}
zle -N rangernav
bindkey '^g' rangernav

# fasd: quick frecency dirs
unalias zz
function zz() {
  local dir
  dir="$(fasd -Rdl "$1" | fzf --query="$1" -1 -0 --no-sort +m)" && cd "${dir}" || return 1
}

# ctrl-R history search
bindkey -M viins '^r' fzf-insert-history
bindkey -M vicmd '^r' fzf-insert-history

# ctrl-X ctrl-e edit current command in vim
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# fzf: fuzzy finder
fzf_action_list=()
for k v (
  "ctrl-l" "execute(bat --color=always {} | less -Rf || less -f {})" # quick preview file
  "ctrl-f" "execute(vimpager --no-passthrough {} || less -f {})" # serious preview file
  "ctrl-y" "execute-silent(echo -n {} | cpy)" # copy selected line to clipboard
); do
  fzf_action_list+=("$k:$v")
done
export FZF_DEFAULT_OPTS="--bind '${(j.,.)fzf_action_list}'"
export fzf_preview_opt="--preview-window down:50% --preview '(bat {} || highlight -O ansi -l {} || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_T_OPTS="$fzf_preview_opt"

export FZF_TMUX=1
export FZF_TMUX_HEIGHT=80

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules,.venv}/*"'
type filez &>/dev/null && export FZF_DEFAULT_COMMAND='filez'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# turn hidden files on/off in OSX Finder
function hiddenOn() { defaults write com.apple.Finder AppleShowAllFiles YES ; }
function hiddenOff() { defaults write com.apple.Finder AppleShowAllFiles NO ; }

# source machine specific env/aliases
[[ -f $HOME/.post_profile ]] && source $HOME/.post_profile
