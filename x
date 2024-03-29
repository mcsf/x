#!/bin/sh

# TODO (2020-11-23) in `mark_open_item`, append date if different from original

# TODO (2020-11-23) detect stdout type in `o`

FZF=${FZF:-fzf --tac}

CMD=$(basename "$0")
CONF="$HOME/.x.conf"
# shellcheck disable=1090
[ -f "$CONF" ] && . "$CONF"
X_BASE=${X_BASE:-$HOME/Desktop}
X_LOG=${X_LOG:-$X_BASE/log.txt}
X_ARCHIVE_TEMPLATE=${X_ARCHIVE_TEMPLATE:-$X_BASE/tasks-%Y-%m-%d.txt}

main() {
	# shellcheck disable=2048 disable=2086
	if ! args=$(getopt IacehlpP: $*); then
		usage
		exit 2
	fi
	# shellcheck disable=2086
	set -- $args
	ACTION=list_items
	ACTION_ARGS=""
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
			-P) ACTION=print_since ; shift; ACTION_ARGS="$1"; shift ;;
			--) shift ; break ;;
		esac
	done
	[ $# -gt 0 ] && ACTION=add_item
	$ACTION "$ACTION_ARGS" "$@"
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
 -a		Commit to-do list to daily log file
 -c		Clear to-do list
 -e		Edit to-do list with text editor, per \$EDITOR
 -h		Show this usage screen
 -l		Search past logs and open them with \$EDITOR
 -p		Print to-do list, unfiltered
 -P DATE	Print a log of closed to-do items matching DATE
EOD
}

list_items() {
	if [ "$CMD" = "o" ] && [ "$INTERACTIVE" = "true" ]; then
		mark_open_item
	else
		[ "$CMD" = "x" ] && mark="[X]" || mark="[ ]"
		grep -F "$mark" "$X_LOG" \
			| awk '{ if ($1 == prev) { $1 = "          " } else { prev = $1 } print }'
	fi
}

mark_open_item() {
	tmp=$(mktemp)
	old_task=$(grep -F '[ ]' "$X_LOG" | $FZF) || exit 1
	read -r old_date old_hour new_task << EOF
$(echo "$old_task" | sed 's/\[ \]/[X]/')
EOF
	(
		grep -Fv "$old_task" "$X_LOG"
		echo "$(date "+%Y-%m-%d %H:%M")" "$new_task" "[$old_date $old_hour]"
	) > "$tmp"
	mv "$tmp" "$X_LOG"
}

add_item() {
	read -r item << EOF # Trim
$*
EOF
	[ "$CMD" = "x" ] && mark="[X]" || mark="[ ]"
	echo "$(date "+%Y-%m-%d %H:%M")" "$mark" "$item" >> "$X_LOG"
	exit 0
}

edit_list() {
	${EDITOR:-vim} "$X_LOG"
}

print_list() {
	cat "$X_LOG"
}

print_since() {
	date="$1"
	file_pattern="$X_ARCHIVE_TEMPLATE"
	logs_dir=$(dirname "$file_pattern")
	cd "$logs_dir" || exit 1
	if which -s dateseq; then
		dateseq "$date" | while read -r day; do
			# shellcheck disable=2086 disable=2144
			[ -f *$day* ] && cat -- *$day*
		done | awk '/\[ \]/{next} /^[[:digit:]]/{$0="  " substr($0,22)} {print}'
	else
		echo "Missing dependency: dateseq"
		exit 1
	fi
}

archive_list() {
	last_date=$(tail -1 "$X_LOG" | cut -d' ' -f1)
	printf "Date (%s): " "$last_date"
	read -r REPLY
	[ -n "$REPLY" ] && last_date="$REPLY"
	if ! dst=$(parse_date "%Y-%m-%d" "$last_date" "+$X_ARCHIVE_TEMPLATE"); then
		echo "Parsing failed"
		exit 1
	fi
	if [ -f "$dst" ]; then
		echo "$dst: file already exists"
		exit 1
	fi
	(echo "== $last_date =="; cat "$X_LOG") > "$dst"
	echo Archived to "$dst"
	printf "Clear closed items? (Y/n) "
	read -r REPLY
	[ "$REPLY" != "n" ] && clear_done_items
}

clear_done_items() {
	tmp=$(mktemp)
	grep -F "[ ]" "$X_LOG" > "$tmp"
	mv "$tmp" "$X_LOG"
}

parse_date() {
	in_format="$1"
	input="$2"
	out_format="$3"
	case "$(uname)" in
		Darwin)
			if ! dst=$(date -jf "$in_format" "$input" "$out_format"); then
				echo "Parsing failed"
				exit 1
			fi ;;
		Linux)
			if ! dst=$(date -D "$in_format" -d "$input" "$out_format"); then
				echo "Parsing failed"
				exit 1
			fi ;;
		*)
			echo "Unsupported environment: $(uname)"
			exit 1 ;;
	esac
	echo "$dst"
}

clear_list() {
	printf "Clear tasks? (y/N) "
	read -r answer
	[ "$answer" != "y" ] && exit 1
	rm -f "$X_LOG"
	touch "$X_LOG"
}

search_logs() {
	file_pattern="$X_ARCHIVE_TEMPLATE"
	logs_dir=$(dirname "$file_pattern")
	# The following assumes any file in $logs_dir is a log. If this ever proves
	# unsufficient, find files inside $logs_dir based on $X_ARCHIVE_TEMPLATE.
	# Until then... YAGNI.
	file=$(cd "$logs_dir" && (find -- * | $FZF)) || exit 1
	file="$logs_dir/$file"
	${EDITOR:-vim} "$file"
}

main "$@"
