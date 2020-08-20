#!/bin/bash

CMD=$(basename "$0")
CONF="$HOME/.x.conf"
# shellcheck disable=1090
[ -f "$CONF" ] && source "$CONF"
X_BASE=${X_BASE:-$HOME/Desktop}
X_LOG=${X_LOG:-$X_BASE/log.txt}
X_ARCHIVE_TEMPLATE=${X_ARCHIVE_TEMPLATE:-+$X_BASE/tasks-%Y-%m-%d.txt}

main() {
	local args
	if ! args=$(getopt Iacehlp "$@"); then
		usage
		exit 2
	fi
	# shellcheck disable=2086
	set -- $args
	ACTION=list_items
	INTERACTIVE=true
	for i; do
		case "$i" in
			-I) INTERACTIVE=false ; shift ;;
			-a) ACTION=archive_list ; shift ;;
			-c) ACTION=clear_list ; shift ;;
			-e) ACTION=edit_list ; shift ;;
			-h) ACTION=usage ; shift ;;
			-l) ACTION=search_logs ; shift ;;
			-p) ACTION=print_list ; shift ;;
			--) shift ; break ;;
		esac
	done
	[[ $# != 0 ]] && ACTION=add_item
	$ACTION "$@"
}

usage() {
	cat <<EOD
usage: x
  List closed to-do items.

usage: o [-I]
  List open to-do items, prompt to select an item and mark it as closed.
  Use -I to suppress interactive behavior and only list items.

usage: o [task ...]
usage: x [task ...]
  Add an item to the to-do list. Invoke with \`o\` for an open item, and with
  \`x\` for a closed item.

usage: $CMD [-acehlp]
 -a	Commit to-do list to daily log file
 -c	Clear to-do list
 -e	Edit to-do list with text editor, per \$EDITOR
 -h	Show this usage screen
 -l	Search past logs and open them with \$EDITOR
 -p	Print to-do list, unfiltered
EOD
}

list_items() {
	if [[ "$CMD" == "o" ]] && [[ "$INTERACTIVE" == "true" ]]; then
		mark_open_item
	else
		local mark
		[[ "$CMD" == "x" ]] && mark="[X]" || mark="[ ]"
		grep -F "$mark" "$X_LOG"
	fi
}

mark_open_item() {
	local tmp old_task new_task
	tmp=$(mktemp)
	old_task=$(grep -F '[ ]' "$X_LOG" | fzf) || exit 1
	new_task=${old_task//\[ \]/[X]}
	cat <(grep -Fv "$old_task" "$X_LOG") <(echo -n "$new_task") <(date "+ [%H:%M]") > "$tmp"
	mv "$tmp" "$X_LOG"
}

add_item() {
	local mark
	[[ "$CMD" == "x" ]] && mark="[X]" || mark="[ ]"
	echo "$(date "+%Y-%m-%d %H:%M")" "$mark" "$@" >> "$X_LOG"
	exit 0
}

edit_list() {
	${EDITOR:-vim} "$X_LOG"
}

print_list() {
	cat "$X_LOG"
}

archive_list() {
	local last_date dst
	last_date=$(tail -1 "$X_LOG" | cut -d' ' -f1)
	if ! dst=$(date -jf "%Y-%m-%d" "$last_date" "$X_ARCHIVE_TEMPLATE"); then
		echo "Parsing failed"
		exit 1
	fi
	if [ -f "$dst" ]; then
		echo "$dst: file already exists"
		exit 1
	fi
	cat <(echo "== $last_date ==") <(cat "$X_LOG") > "$dst"
	echo Archived to "$dst"
}

clear_list() {
	local answer
	read -rp "Clear tasks? (y/N) " answer
	[[ "$answer" != "y" ]] && exit 1
	rm -f "$X_LOG"
	touch "$X_LOG"
}

search_logs() {
	local file_pattern
	file_pattern="$X_ARCHIVE_TEMPLATE"
	file_pattern=${file_pattern/#+/}
	file_pattern=${file_pattern//%Y-%m-%d/*}
	# shellcheck disable=2012,2086
	file=$(ls -r1 $file_pattern | fzf) || exit 1
	${EDITOR:-vim} "$file"
}

main "$@"
