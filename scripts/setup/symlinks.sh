#!/bin/bash

ln -sf `pwd`/zshrc ~/.zshrc

ln -sf `pwd`/tmux.conf ~/.tmux.conf

ln -sf `pwd`/vimrc ~/.vimrc

mkdir -p ~/.config/nvim
ln -sf `pwd`/vimrc ~/.config/nvim/init.vim

