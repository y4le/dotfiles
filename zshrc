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

# vi mode :D
bindkey -v
export KEYTIMEOUT=1
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M vicmd '^r' history-incremental-search-backward

# bind shortcuts
bindkey -s '^k' 'ranger\n'

# set up fuzzy find
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
alias v="fzf -m | xargs -o vim"
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# aliases
alias gitd="git --no-pager diff HEAD^ --name-only"
alias recentbranches="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias tt="tmux attach -t"

# environment variables
export EDITOR="vim"

export PATH=/opt/local/bin:/opt/local/sbin:$PATH

# include .aliases if it exists
if [ -f $HOME/.aliases ]; then
  . $HOME/.aliases
fi

# use powerline if we got it
#if [ -f /usr/local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh ]; then
#  . /usr/local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh
#fi

