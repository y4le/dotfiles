# antigen setup
source "$HOME/.antigen/antigen.zsh"

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

# bind shortcuts
bindkey -s '^k' 'ranger\n'


# set up fuzzy find
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# aliases
alias cdwrd="cd ~/dev/main-web-redesign/Savagebeast/Engineering/projects/"
alias openwrd="open ~/dev/main-web-redesign/Savagebeast/Engineering/projects/sb.ipr"
alias crawl="/Users/ythomas/games/Dungeon\ Crawl\ Stone\ Soup\ -\ Console.app/Contents/Resources/crawl"
alias cdweb="cd /Users/ythomas/dev/web-client"
alias gitd="git --no-pager diff HEAD^ --name-only"
alias recentbranches="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"

# environment variables
export EDITOR="vim"

# - Pandora
# export P4CONFIG=~/.p4config
export P4PORT="ssl:perforce.savagebeast.com:1666"
export P4CLIENT="ythomas-laptop"
export P4EDITOR="vim"
export P4MERGE="p4merge"
export PANDORA_DEV_ENV_DEPS_DIR=~/local
export VM_ROOT=/Users/ythomas/vm_localhost
export VMPYTHON=~/local/python/bin/python
export PYTHON_PATH=~/local/python/lib/python2.7/site-packages

# - Path
export PATH=~/vagrant/bin:$PATH
export PATH=/local/pgsql/bin:$PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH}
export PATH=${HOME}/local/python/bin:${PATH}
export PATH=${HOME}/local/coreutils/bin:${PATH}
export PATH=${HOME}/local/postgres/bin:${PATH}
export PATH=${HOME}/local/jython2.2.1:${PATH}
export PATH=~/local/python/bin:${PATH}

