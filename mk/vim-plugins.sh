#!/bin/sh

set -eu

repo=$1
target_home=$2
plug_file=$3
plugged_dir=$4
pins_file=$5

if ! command -v vim >/dev/null 2>&1; then
	echo "vim not found. Install it with your system package manager."
	exit 1
fi
if [ ! -f "${target_home}/.vim/config/plugins.vim" ]; then
	echo "Vim config is not linked; run 'make link' first"
	exit 1
fi
autoload_dir="$(dirname "${plug_file}")"
case "$autoload_dir" in
	"${repo}"|"${repo}"/*)
		echo "$autoload_dir is inside the dotfiles repository; run 'make link' first"
		exit 1 ;;
	*) ;;
esac
if [ -L "$autoload_dir" ]; then
	echo "$autoload_dir is a legacy or broken symlink; run 'make link' first"
	exit 1
fi
existing="$autoload_dir"
while [ ! -d "$existing" ]; do
	parent="$(dirname "$existing")"
	[ "$parent" != "$existing" ] || break
	existing="$parent"
done
if [ -d "$existing" ]; then
	repo_physical="$(cd -P "${repo}" && pwd -P)" || exit 1
	existing_physical="$(cd -P "$existing" && pwd -P)" || exit 1
	case "$existing_physical/" in
		"$repo_physical/"*)
			echo "$autoload_dir would resolve into $repo_physical (legacy folded layout)."
			echo "Remove the generated plug.vim, run 'make link', then rerun 'make vim-plugins'."
			exit 1 ;;
		*) ;;
	esac
fi
DOTFILES_PINS_FILE="${pins_file}" \
	sh mk/pinned.sh install vim-plug "${plug_file}" 0644
fzf_dir="${plugged_dir}/fzf"
fzf_bin="$fzf_dir/bin/fzf"
if [ ! -L "$fzf_dir" ] && [ -d "$fzf_dir/.git" ] && [ ! -L "$fzf_dir/.git" ] && \
	{ [ -e "$fzf_bin" ] || [ -L "$fzf_bin" ]; }; then
	tracked="$(GIT_DIR="$fzf_dir/.git" GIT_WORK_TREE="$fzf_dir" \
		git --no-optional-locks --no-replace-objects -c core.fsmonitor=false \
			ls-files --stage -- bin/fzf)" || {
			echo "could not inspect plugin-local fzf binary: $fzf_bin"
			exit 1
		}
	if [ -z "$tracked" ]; then
		echo "removing plugin-local fzf override: $fzf_bin (mise supplies fzf)"
		rm -f "$fzf_bin"
	fi
fi
bootstrap="$(mktemp)"
trap 'rm -f "$bootstrap"' EXIT
trap 'exit 1' HUP INT TERM
printf '%s\n' \
	'let $VIMHOME = expand("~/.vim")' \
	'execute "set runtimepath^=" . fnameescape($VIMHOME)' \
	'execute "source " . fnameescape($VIMHOME . "/config/plugins.vim")' > "$bootstrap"
echo "syncing Vim plugins"
DOTFILES_VERIFY_VIM_PLUGINS="${repo}/mk/verify-vim-plugins.vim" \
	DOTFILES_RESTORE_VIM_PINS="${repo}/mk/restore-vim-pins.vim" \
	vim -Nu NONE -n -S "$bootstrap" '+PlugInstall --sync' \
	'+execute "source " . fnameescape($DOTFILES_RESTORE_VIM_PINS)' \
	'+execute "source " . fnameescape($DOTFILES_VERIFY_VIM_PLUGINS)' +qa
