#!/bin/bash

# zsh
ln -sf `pwd`/zshrc ~/.zshrc

# tmux
ln -sf `pwd`/tmux.conf ~/.tmux.conf

# git
ln -sf `pwd`/gitconfig ~/.gitconfig

# vim
ln -sf `pwd`/vimrc ~/.vimrc

# nvim
mkdir -p ~/.config/nvim
ln -sf `pwd`/vimrc ~/.config/nvim/init.vim

