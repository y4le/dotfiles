# antigen setup
source /usr/local/share/antigen/antigen.zsh

# dat oh-my-zsh + theme
antigen use oh-my-zsh
antigen theme S1cK94/minimal minimal

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
antigen bundle zsh-users/zsh-completions src
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

# aliases
alias gitd="git --no-pager diff HEAD^ --name-only"
alias recentbranches="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"

# tophatter aliases
alias migrate="bin/rake db:migrate"
alias reset="bin/rake tmp:clear tophatter:reset"
alias restart="touch ~/.pow/restart.txt"
alias auctioneer="bin/rails r lib/tasks/auctioneer.rb"
alias commit!="OVERCOMMIT_DISABLE=1 git commit"
alias push!="OVERCOMMIT_DISABLE=1 git push"
alias hkl="HEROKU_ORGANIZATION=tophatter heroku login --sso"
alias t="cd ~/Documents/tophatter"
alias airflow_ec2_dev="ssh ubuntu@52.55.71.237 -i ~/ubuntu-lucid-lynx.pem"

# environment variables
export EDITOR="vim"

# - Path
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH}
export PATH=${HOME}/local/python/bin:${PATH}
export PATH=~/local/python/bin:${PATH}

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="/usr/local/opt/scala@2.11/bin:$PATH"
