#!/bin/sh

set -eu

fail=0
sh_files="$(git ls-files | while IFS= read -r file; do
	[ ! -f "$file" ] || awk \
		'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)(sh|dash)([[:space:]]|$)/ { print FILENAME }' "$file"
done)" || {
	echo "check-shell: sh discovery failed"
	fail=1
}
bash_files="$(git ls-files | while IFS= read -r file; do
	[ ! -f "$file" ] || awk \
		'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)bash([[:space:]]|$)/ { print FILENAME }' "$file"
done)" || {
	echo "check-shell: bash discovery failed"
	fail=1
}
zsh_path_files="$( \
	git ls-files -- \
		zsh/.zshenv \
		zsh/.zshrc \
		osx/.zprofile \
		'zsh/.config/zsh/themes/*' \
		'*/.config/zsh/sources/*' \
		'*/.config/shell/functions/*' \
)" || {
	echo "check-shell: zsh path discovery failed"
	fail=1
}
zsh_shebang_files="$( \
	git ls-files | while IFS= read -r file; do
		[ ! -f "$file" ] || awk \
			'FNR == 1 && /^#!(\/usr\/bin\/env[[:space:]]+|\/bin\/|\/usr\/bin\/)zsh([[:space:]]|$)/ { print FILENAME }' "$file"
	done \
)" || {
	echo "check-shell: zsh shebang discovery failed"
	fail=1
}
zsh_files="$( \
	printf '%s\n%s\n' "$zsh_path_files" "$zsh_shebang_files" | \
		sed '/^$/d' | LC_ALL=C sort -u \
)" || {
	echo "check-shell: zsh list normalization failed"
	fail=1
}
for entry in "sh:$sh_files" "bash:$bash_files" "zsh:$zsh_files"; do
	label=${entry%%:*}
	files=${entry#*:}
	if [ -z "$files" ]; then
		echo "check-shell: no tracked $label files discovered"
		fail=1
	fi
done
echo "check-shell: sh -n"
for f in $sh_files; do
	sh -n "$f" || fail=1
done
echo "check-shell: bash -n"
for f in $bash_files; do
	bash -n "$f" || fail=1
done
echo "check-shell: zsh -n"
for f in $zsh_files; do
	zsh -n "$f" || fail=1
done
if command -v shellcheck >/dev/null 2>&1; then
	if [ -n "$sh_files" ] && [ -n "$bash_files" ]; then
		echo "check-shell: shellcheck"
		shellcheck -x -S warning -s sh $sh_files || fail=1
		shellcheck -x -S warning -s bash $bash_files || fail=1
	fi
else
	echo "check-shell: shellcheck not found"
	if [ -n "${CI:-}" ]; then
		fail=1
	else
		echo "check-shell: skipping shellcheck outside CI"
	fi
fi
exit $fail
