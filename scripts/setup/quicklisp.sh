#!/bin/bash

lisp_packages=(
  sbcl # common lisp interpreter
  # roswell # lisp implementation installer/manager/launcher
)

brew install ${lisp_packages[@]}
brew upgrade ${lisp_packages[@]}

mkdir -p ~/.quicklisp

curl https://beta.quicklisp.org/quicklisp.lisp -o ~/.quicklisp/quicklisp.lisp

tput setaf 2 # green text
echo
echo 'in the lisp prompt, evaluate: '
echo '(quicklisp-quickstart:install :path "~/.quicklisp/")'
echo '(ql:add-to-init-file)'
echo
tput sgr0 # default text

sbcl --load ~/.quicklisp/quicklisp.lisp

