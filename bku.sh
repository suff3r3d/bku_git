#!/bin/bash

##################################################################################
#
#
#
# - ./bku
#   - commit_history
#   - tracked_files
#   - commits/
#     - $(hashes of files) # (hash of name if first commit)
#       - (original file if first commit)
#       - commit_message
#       - next_diff # stores differences from current to next (newer) (created by diff)
# 			- prev_diff
#       - next_hash # hash of next commit
#
#
##################################################################################

# Restoring files copy previous version

###########################  Utilities  ##########################################
hash_with_date() {
	echo "$1$(date +%s)" | sha256sum | cut -d ' ' -f 1
}

hash_file() {
	sha256sum $1 | cut -d ' ' -f 1
}

hash_filename() {
	echo "$1" | sha256sum | cut -d ' ' -f 1
}

get_latest_directory() {
	dir_path=$1
	echo $(ls -td "$dir_path"/*/ | head -n 1)
}

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
	mkdir .bku/commit_id

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

	printf "$filepath" >> .bku/tracked_files
	# hash_dir=.bku/commits/$(echo "$filepath" | sha256sum | cut -d ' ' -f 1)
	hash_dir=.bku/commits/$(hash_filename "$filepath")
	mkdir $hash_dir
	cp $filepath $hash_dir/original

	echo "Added $filepath to backup tracking."
}

commit() {
	message=$1
	filepath=$2
	id=$3

	if [ ! -f "$filepath" ]; then
		echo "Error: $filepath doesn't exist."
		exit 1
	fi

	if [ "$(strings .bku/tracked_files | grep $filepath)" == "" ]; then
		echo "Error: $filepath hasn't been tracked yet."
		exit 1
	fi

	latest_hash_dir=$(recreate $filepath)
	# latest file is now in ./tmp/latest

	# cat ./.tmp/latest

	if cmp -s "./.tmp/latest" "$filepath"; then
		echo "Error: $filepath is the same as the latest commit."
		exit 1
	fi

	current_hash_file=$(hash_with_date "$filepath")
	current_hash_dir=.bku/commits/$current_hash_file
	mkdir $current_hash_dir

	diff ./.tmp/latest $filepath > $latest_hash_dir/next_diff > /dev/null 2>&1
	diff $filepath ./.tmp/latest > $current_hash_dir/prev_diff > /dev/null 2>&1
	printf "$current_hash_file" > $latest_hash_dir/next_hash
	echo "$message" > $current_hash_dir/commit_message

	# echo "$(date +"%H:%M-%d/%m/%Y"): $message ($filepath)." > .tmp/tmp_history
	# cat .bku/commit_history >> .tmp/tmp_history
	# cp .tmp/tmp_history .bku/commit_history

	echo "$filepath" >> ".bku/commit_id/$id"

	rm -rf .tmp
}

recreate() {
	# recreate a file to the latest commit

	# using hash value to recreate 
	filepath=$1

	current_hash_file=$(hash_filename "$filepath")
	current_hash_dir=.bku/commits/$current_hash_file

	# create a .tmp directory and work in it for security

	rm -rf ./.tmp/*
	mkdir -p .tmp

	current_file=$current_hash_dir/original
	cp $current_file .tmp/current_file
	current_file=.tmp/current_file


	while [[ -f $current_hash_dir/next_hash ]] ; do
		patch $current_file $current_hash_dir/next_diff > /dev/null 2>&1

		current_hash_file=$(cat "$current_hash_dir/next_hash")
		current_hash_dir=.bku/commits/$current_hash_file
	done

	mv $current_file .tmp/latest

	printf "$current_hash_dir" # return hash dir
	# now the latest is $current_file (# .tmp/latest)
}

restore() {
	filepath=$1

	rm -rf .tmp
	current_hash_dir=$(recreate $filepath)

	if [[ ! -e "$current_hash_dir/prev_diff" ]]; then
		echo "Error: No previous version available for $filepath"
		exit 1
	fi

	patch ".tmp/latest" "$current_hash_dir/prev_diff" > /dev/null 2>&1

	cp .tmp/latest $filepath

	printf "Restored $filepath to its previous version."
}

########################### Main ################################

if [ ! -d ".bku" ]; then
	echo ".bku directory doesn't exist!"
	exit 1
fi

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

if [ "$1" == "commit" ]; then
	message=$2
  filename=$3
	id=$(echo "$(date +%s)")

  if [ "$filename" == "" ]; then
    echo "Commit all files."
		exit 0
  fi

	commit $message $filename $id
	exit 0
fi

if [ "$1" == "restore" ]; then
	if [ "$2" == "" ]; then
		echo "Restore latest commit."
		restore_latest_commit
		exit 0
	fi

	filepath=$2
	restore $filepath
fi

if [ "$1" == "history" ]; then
	cat .bku/commit_history
fi