# antigen setup
source /usr/local/share/antigen/antigen.zsh

# dat oh-my-zsh + theme
antigen use oh-my-zsh
antigen theme subnixr/minimal

# antigen plugins
antigen bundle git
antigen bundle pip
antigen bundle python
antigen bundle node
antigen bundle npm
antigen bundle common-aliases
antigen bundle command-not-found
antigen bundle autojump
antigen bundle brew
antigen bundle compleat
antigen bundle osx
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search ./zsh-history-substring-search.zsh
antigen bundle tarruda/zsh-autosuggestions

antigen apply

# vim mode + vim editor
bindkey -v
export KEYTIMEOUT=1
export EDITOR="vim"

# ctrl-R history search
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M vicmd '^r' history-incremental-search-backward

# bind shortcuts
bindkey -s '^k' 'ranger\n'

# ctrl-X ctrl-e edit current command in vim
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# set up fuzzy find
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
alias v="fzf -m | xargs -o vim"
alias preview="fzf --preview 'bat --color \"always\" {}'"
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# git aliases
alias gip="git --no-pager" 
function gbase() { git checkout master && git pull && git checkout $(git rev-parse --abbrev-ref HEAD) && git rebase master }
function gbranch() { git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))' }

# turn hidden files on/off in Finder
function hiddenOn() { defaults write com.apple.Finder AppleShowAllFiles YES ; }
function hiddenOff() { defaults write com.apple.Finder AppleShowAllFiles NO ; }

# better replacements for builtins
alias top='sudo htop' # replace `top` with better alternative
alias ping='prettyping --nolegend' # replace `ping` with better alternative
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"

if [ -f $HOME/.profile ]; then
  . $HOME/.profile
fi

