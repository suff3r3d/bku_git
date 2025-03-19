#!/bin/bash

##################################################################################
#
#
#
# - ./bku
#   - commit_history
#   - tracked_files
#   - commits/
#     - $(hashes of files)
#       - $(hashes of previous files or hashes of themselves if they are the first commit)
#       - previous_diff # stores differences from current to previous (older)
#       - next_diff # stores differences from current to next (newer)
#
#
#
##################################################################################

if [ "$1" == "init" ]; then
	if [ -d ".bku" ]; then
  	echo "Error: Backup already initialized in this folder."
  	exit 1
	fi

  mkdir .bku

  touch .bku/commit_history
  printf "$(date +"%H:%M-%d/%m/%Y"): BKU Init.\n" >> ".bku/commit_history"

	touch .bku/tracked_files

	mkdir .bku/commits

  echo "Backup initialized."
fi

add() {
	filepath=$1

	if [ ! -d .bku ]; then
		echo ".bku directory doesn't exist."
    exit 1
  fi

	if [ -d "$filepath" ]; then
		echo "$filepath is a directory".
		exit 1 
	fi

	if [ ! -f "$filepath" ]; then
		echo "Error: $filepath doesn't exist."
		exit 1
	fi

	if [ "$(strings .bku/tracked_files | grep $filepath)" != "" ]; then
		echo "Error: $filepath is already tracked."
		exit 1
	fi

	echo "Adding $filepath."

	printf "$filepath" >> ./bku/tracked_files

	echo "Added $filepath to backup tracking."
}

get_line() {
	# 1-indexed of line
	filepath=$1
	idx=$(($2))

	line=""

	while IFS= read -r cur
	do
		idx=$(($idx-1))
		if [ $idx -eq 0 ]; then
			return cur
		fi
	done < "$filepath"

	return ""
}

diff() {
	current=$1
	latest=$2
	# First, show deleted lines. (Lines that latests have but current doesn't)
}

if [ "$1" == "add" ]; then
  filename=$2
  if [ "$2" == "" ]; then
    echo "Add all files."
		exit 0
  fi
	add $filename
	exit 0
fi

if [ "$1" == "diff" ]; then
	if [ "$2" == "" ]; then
		echo "Diff all files."
		exit 0
	fi
fi