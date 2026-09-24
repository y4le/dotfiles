#!/usr/bin/env bash
# Open each pair of files in a vertical Vim diff tab.
set -u

if (($# == 0 || $# % 2 != 0)); then
  echo 'usage: compair.sh first second [third fourth ...]' >&2
  exit 2
fi

for file in "$@"; do
  if [[ ! -f $file ]]; then
    printf 'compair: file not found: %s\n' "$file" >&2
    exit 1
  fi
done

script=$(mktemp) || exit 1
trap 'rm "$script"' EXIT
cat > "$script" <<'VIM'
set diffopt=filler,vertical
let s:files = argv()
for s:i in range(0, len(s:files) - 1, 2)
  if s:i > 0
    tabnew
  endif
  execute 'edit' fnameescape(s:files[s:i])
  execute 'diffsplit' fnameescape(s:files[s:i + 1])
endfor
VIM

vim -S "$script" -- "$@"
