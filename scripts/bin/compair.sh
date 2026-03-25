#!/bin/bash
# open vimdiffs comparing pairs of files
# input is list of files, first compared to second, third to fourth...
# `vim_compair a b c d` opens vimdiff tabs for a/b and c/d
function vim_compair {
	local last=""
	local -a args=()
	local first_pair=true
	for file in "$@"; do
		if [[ -z "$last" ]]; then
			last="$file"
		else
			if $first_pair; then
				args=(-c 'set diffopt=filler,vertical' -c "edit $last" -c "diffsplit $file")
				first_pair=false
			else
				args+=(-c "tabe $last" -c "diffsplit $file")
			fi
			last=""
		fi
	done

	vim "${args[@]}"
}

vim_compair "$@"
