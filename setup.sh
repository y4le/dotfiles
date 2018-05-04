brew install tmux
brew install zsh
brew install antigen
brew install vim
brew install neovim
brew install fzf
brew install ranger
brew install fpp

ln -sf `pwd`/vimrc ~/.vimrc

mkdir -p ~/.config/nvim
ln -sf `pwd`/vimrc ~/.config/nvim/init.vim

ln -sf `pwd`/zshrc ~/.zshrc

ln -sf `pwd`/tmux.conf ~/.tmux.conf

