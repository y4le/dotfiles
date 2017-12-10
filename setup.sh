
brew install tmux
brew install zsh
brew install antigen
brew install vim
brew install neovim
brew install fzf
brew install ranger
brew install fpp

rm -f ~/.vimrc
ln -s `pwd`/vimrc ~/.vimrc

rm -f ~/.zshrc
ln -s `pwd`/zshrc ~/.zshrc

rm -f ~/.tmux.conf
ln -s `pwd`/tmux.conf ~/.tmux.conf

