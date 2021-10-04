# open vimdiffs comparing pairs of files
# input is list of files, first compared to second, third to fourth...
# `vim_compair a b c d` opens vimdiff tabs for a/b and c/d
function vim_compair {
	last=""
	cmd=""
	for file in "$@"; do
		if [ -z "$last" ]; then
			last=$file
		else
			if [ -z "$cmd" ]; then
				cmd="vim -c 'set diffopt=filler,vertical' -c 'edit $last' -c 'diffsplit $file' "
			else
				cmd="${cmd} -c 'tabe $last' -c 'diffsplit $file' "
			fi
			last=""
		fi
	done

	eval $cmd
}

vim_compair $@
