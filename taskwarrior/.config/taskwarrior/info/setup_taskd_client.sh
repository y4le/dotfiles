#!/bin/sh

if ! [ -x "$(command -v 7z)" ]; then
  echo 'Error: 7z is not installed.' >&2
  exit 1
fi

# unzip certs if necessary
[[ -d $(realpath "./certs/") ]] || 7z x certs.7z

cp certs/yale.cert.pem ~/.task
cp certs/yale.key.pem ~/.task
cp certs/ca.cert.pem ~/.task

task config taskd.certificate -- ~/.task/yale.cert.pem
task config taskd.key -- ~/.task/yale.key.pem
task config taskd.ca -- ~/.task/ca.cert.pem

task config taskd.server -- localhost:53589

task config taskd.credentials -- Goog/Yale/0a817d0a-1cb8-4024-85c0-c8179109aa7a
