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
#
#
#
##################################################################################


# Haven't considered the case where the file is the same as the previous commit
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

	printf "$filepath" >> .bku/tracked_files
	hash_dir=.bku/commits/$(echo "$filepath" | sha256sum | cut -d ' ' -f 1)
	mkdir $hash_dir
	cp $filepath $hash_dir/original

	echo "Added $filepath to backup tracking."
}

commit() {
	message=$1
	filepath=$2

	if [ ! -f "$filepath" ]; then
		echo "Error: $filepath doesn't exist."
		exit 1
	fi

	if [ "$(strings .bku/tracked_files | grep $filepath)" == "" ]; then
		echo "Error: $filepath hasn't been tracked yet."
		exit 1
	fi

	recreate $filepath
	# latest file is now in ./tmp/latest

	cat ./.tmp/latest

	if cmp -s "./.tmp/latest" "$filepath"; then
		echo "Error: $filepath is the same as the latest commit."
		exit 1
	fi

	current_hash_file=$(sha256sum $filepath | cut -d ' ' -f 1)
	current_hash_dir=.bku/commits/$current_hash_file
	mkdir $current_hash_dir

	diff ./.tmp/latest $filepath > $current_hash_dir/next_diff
	echo "$message" > $current_hash_dir/commit_message

	rm -r .tmp
}

recreate() {
	# recreate a file to the latest commit

	# using hash value to recreate 
	filepath=$1

	current_hash_file=$(echo "$filepath" | sha256sum | cut -d ' ' -f 1)
	current_hash_dir=.bku/commits/$current_hash_file

	# create a .tmp directory and work in it for security

	mkdir -p .tmp

	current_file=$current_hash_dir/original
	cp $current_file .tmp/current_file
	current_file=.tmp/current_file


	while [[ -f $current_hash_dir/next_diff ]] ; do
		patch $current_file $current_hash_dir/next_diff

		current_hash_file=$(sha256sum $current_file | cut -d ' ' -f 1)
		current_hash_dir=.bku/commits/$current_hash_file
	done

	mv $current_file .tmp/latest

	# now the latest is $current_file (# .tmp/latest)
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

if [ "$1" == "commit" ]; then
	message=$2
  filename=$3

  if [ "$filename" == "" ]; then
    echo "Commit all files."
		exit 0
  fi

	commit $message $filename
	exit 0
fi