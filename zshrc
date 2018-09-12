# ZPLUG

# install zplug if missing
if [[ ! -d ~/.zplug ]]; then
  git clone https://github.com/b4b4r07/zplug ~/.zplug
fi

# set home
export ZPLUG_HOME=~/.zplug
source $ZPLUG_HOME/init.zsh

# clear old packages
zplug clear

# self manage
zplug zplug/zplug, hook-build:"zplug --self-manage"

# theme
zplug subnixr/minimal

# plugins
zplug MisterRios/stashy                         # `git stash pop stash@{2}` -> `stashy pop 2`
zplug b4b4r07/zsh-vimode-visual, defer:3        # add visual vim mode to the cli
zplug changyuheng/zsh-interactive-cd            # interactive fzf powered `cd`
zplug peterhurford/git-it-on.zsh                # open dir in github `cd ~/dev/dotfiles && gitit`
zplug so-fancy/diff-so-fancy                    # pretty diffs
zplug wfxr/forgit, defer:1                      # fzf + git: ga(dd) glo(g) gi(gnore) gd(iff) gcf(ile)
zplug ytet5uy4/fzf-widgets                      # fzf widgets - used to get fzf-insert-history
zplug zdharma/fast-syntax-highlighting, defer:2 # fast cli syntax highlighting
zplug zlsun/solarized-man                       # colorful man pages
zplug zsh-users/zsh-autosuggestions             # typeahead command suggestions from history

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

setopt share_history    # share between shells
setopt append_history   # append, don't overwrite
setopt extended_history # timestamps

bindkey -v # vim mode
export KEYTIMEOUT=1 # vim mode timeout 1ms instead of .4s
export EDITOR="vim" # vim 4 life


# SHORTCUTS

bindkey -s '^t' 'ranger\n' # ctrl-t ranger

# ctrl-R history search
bindkey -M viins '^r' fzf-insert-history
bindkey -M vicmd '^r' fzf-insert-history

# ctrl-X ctrl-e edit current command in vim
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# set up fuzzy find
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
alias v="fzf -m | xargs -o vim" # alias to open files in vim
alias preview="fzf --preview 'bat --color \"always\" {}'" # preview contents of files
function briff() { git branch | cut -c 3- | fzf --preview "git diff --color master...{}" } # e.g. > git checkout `briff`

# turn hidden files on/off in OSX Finder
function hiddenOn() { defaults write com.apple.Finder AppleShowAllFiles YES ; }
function hiddenOff() { defaults write com.apple.Finder AppleShowAllFiles NO ; }

# better replacements for builtins
alias top='sudo htop' # replace `top` with better alternative
alias ping='prettyping --nolegend' # replace `ping` with better alternative
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"

# source machine specific env/aliases
if [ -f $HOME/.profile ]; then
  . $HOME/.profile
fi

